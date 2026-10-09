#!/bin/bash
# Minimal Claude Code status line, sized to the terminal width.
#
#   <repo> (<branch>)  <session>  <effort> <model> <window>  <modes>  ctx <bar> N%
#     5h/7d <bar> N%/N% ↻<5h>/<7d>
#
# GLYPHS
# Unlabeled by design, so the legend lives here:
#   effort  ○ low   ◔ medium   ◑ high   ◕ xhigh   ● max   (absent when unrecognized)
#   modes   ✻ thinking enabled    ↯ fast mode on    (absent when off)
#
# WIDTH
# Claude Code exports COLUMNS into this subprocess. Nothing here is a TTY (stdout is
# captured, /dev/tty is not configured), so tput and stty cannot determine the width on
# their own; tput only works when it inherits COLUMNS. The layout is built at a base size,
# then degraded step by step if it overflows, or grown toward MAX_BAR / MAX_NAME when
# there is room to spare.
#
# THE USAGE BAR
# A two-row stacked gauge packed into one row of cells. Every cell is the same glyph (▄);
# state is carried by color, not glyph, so filled and unfilled stretches are the same size:
#   upper half (background) = 5-hour window
#   lower half (foreground) = 7-day window
# Each half colors independently: green < 50%, yellow < 80%, red >= 80%, theme gray unused.
# The halves need different intensities from each other to stay separable when both land in
# the same band, so the upper half uses the bright background codes (101-103) and the lower
# half normal foregrounds (31-33).
#
# The model's trailing parenthetical is replaced with the real window size from the payload,
# so "Opus 5 (1M context)" renders as "Opus 5 1M".
#
# All values come from the status line's stdin JSON; nothing is read from transcripts.
#
# DEPENDENCIES
# bash 3.2+ (no 4.x features; \uXXXX is decoded by hand since printf \u needs 4.2), plus git,
# date and basename. No jq: the payload is parsed in pure bash, so behavior is identical on every
# machine rather than depending on what happens to be installed.

# Each sizable element has up to three bounds: the size the layout is built at before the width is
# known (BASE), the ceiling it may grow to when the window has room (MAX), and the floor it
# degrades to before being dropped entirely (MIN). An element with no MIN is never shrunk on the
# way down, only dropped.
BASE_BAR=20
MAX_BAR=50
MIN_BAR=4

# The session name has no floor: it is not truncated on the way down. The name is also shown
# beside the input field, so at the width where anything has to give it is the cheapest thing to
# drop outright and the least missed. It is the ladder's first step.
BASE_NAME=32
MAX_NAME=64

# The repo name has no base or ceiling: it shows in full until the ladder is exhausted, and
# is only then clipped, down to this floor, as the last resort before the line would overflow.
MIN_REPO=3

# The branch is truncated and dropped like the session name, but with its own bounds: branch
# names are usually short (they are named after tickets here) so the base is tighter.
BASE_BRANCH=24
MIN_BRANCH=8

# Mode glyphs, shown only when the mode is on. Deliberately BMP symbols rather than emoji:
# emoji are East Asian Wide, so they occupy two columns while counting as one character, which
# would make the width arithmetic under-count and overrun the budget.
GLYPH_THINK='✻'
GLYPH_FAST='↯'

# Effort as a fill gauge, low -> max. Circles rather than block heights so the glyph cannot be
# mistaken for a fragment of the ctx or usage bars, and rather than arrows because ↑↓ beside a
# branch name reads as ahead/behind upstream.
GLYPH_EFFORT_LOW='○'
GLYPH_EFFORT_MED='◔'
GLYPH_EFFORT_HIGH='◑'
GLYPH_EFFORT_XHIGH='◕'
GLYPH_EFFORT_MAX='●'

# A base below its own floor would make the degradation ladder step upward, so clamp.
[ "$MIN_BAR" -gt "$BASE_BAR" ] && MIN_BAR=$BASE_BAR
[ "$MIN_BRANCH" -gt "$BASE_BRANCH" ] && MIN_BRANCH=$BASE_BRANCH

ESC=$'\033'
RESET="${ESC}[0m"
DIM="${ESC}[2m"
BOLD="${ESC}[1m"
CYAN="${ESC}[36m"
MAGENTA="${ESC}[35m"
WHITE="${ESC}[37m"

# Unused track: bright black, a palette slot rather than a fixed value, so it follows the
# terminal theme's gray on both light and dark backgrounds.
OFF_FG=90
OFF_BG=100

# A UTF-8 locale is required for correct string handling: without one, bash measures and slices
# strings by byte, so truncating a name containing non-ASCII can cut a character in half and emit
# an invalid byte sequence. Probe with a two-byte character and repair only if needed; hosts
# normally pass a usable locale through, in which case the probe passes and nothing changes.
#
# This makes lengths correct in characters, not display columns. East Asian characters occupy two
# columns each while counting as one, so a CJK-heavy session name can still overrun the budget.
# Accounting for that properly needs a wcwidth table, which is not worth carrying here.
_probe=$'\xc3\xa9'
if [ ${#_probe} -ne 1 ]; then
  for _loc in C.UTF-8 en_US.UTF-8 en_US.utf8 UTF-8; do
    export LC_ALL=$_loc
    [ ${#_probe} -eq 1 ] && break
  done
fi
unset _probe _loc

input=$(cat)

# ============================================================================================
# PARSING THE PAYLOAD
#
# Parsed in pure bash rather than with jq, so the script runs anywhere bash does. jq ships with
# macOS but is not preinstalled on most Linux images, and a single implementation means identical
# behavior on every machine instead of behavior that depends on what happens to be installed.
#
# Sets exactly these nine globals:
#
#   cwd           workspace.current_dir, else top-level cwd, else "."
#   session_name  session_name, else ""; any newline, CR or tab collapsed to a space
#   ctx_pct       context_window.used_percentage,           floored; -1 when absent
#   five_pct      rate_limits.five_hour.used_percentage,    floored; -1 when absent
#   week_pct      rate_limits.seven_day.used_percentage,    floored; -1 when absent
#   five_reset    rate_limits.five_hour.resets_at,          floored; -1 when absent
#   week_reset    rate_limits.seven_day.resets_at,          floored; -1 when absent
#   model_name    model.display_name, else model.id, else ""; trailing " (...)" removed
#   ctx_size      context_window.context_window_size,       floored; -1 when absent
#   thinking_on   1 when thinking.enabled is true, else 0
#   fast_on       1 when fast_mode is true, else 0
#   effort        effort.level verbatim, else ""
#
# Each field is read by first narrowing to the object that contains it, then reading the key from
# that narrowed text. Narrowing first is what makes this order-independent: used_percentage
# appears three times in the payload and resets_at twice, but each is unique *within* its own
# object, so nothing depends on which key precedes or follows another.
#
# The helpers return through the global $_ret rather than echoing, because a command substitution
# per field costs more than the whole rest of the parse.
#
# Known limits, none of which the payload has exercised: the input is not validated, so malformed
# JSON yields a partial line rather than an error; and a key name appearing verbatim inside a
# string value could be matched in preference to the real key.
# ============================================================================================

# $_ret = the text after the first `"key":`, with whitespace following the colon removed.
# Returns 1 when the key is absent. JSON permits whitespace after a colon and the payload is
# only minified by convention, so it is trimmed rather than assumed away.
j_after() {
  local s=$1 r
  r=${s#*\"$2\":}
  if [ "$r" = "$s" ]; then _ret=''; return 1; fi
  _ret=${r#"${r%%[![:space:]]*}"}
}

# $_ret = the balanced `{ ... }` object after `"key":`, honoring nesting and quoted strings.
# Cutting at the first `}` would be wrong for context_window, whose nested current_usage object
# closes before the used_percentage this needs to reach.
j_scope() {
  j_after "$1" "$2" || return 1
  local r=$_ret n i=0 depth=0 instr=0 esc=0 ch
  [ "${r:0:1}" = '{' ] || { _ret=''; return 1; }
  n=${#r}
  while [ "$i" -lt "$n" ]; do
    ch=${r:i:1}
    if [ "$esc" -eq 1 ]; then esc=0
    elif [ "$ch" = '\' ]; then esc=1
    elif [ "$ch" = '"' ]; then instr=$((1 - instr))
    elif [ "$instr" -eq 0 ]; then
      case $ch in
        '{') depth=$((depth + 1)) ;;
        '}') depth=$((depth - 1)); [ "$depth" -eq 0 ] && break ;;
      esac
    fi
    i=$((i + 1))
  done
  _ret=${r:0:i+1}
}

# $_ret = integer value of "key" in $1, or -1 when absent or non-numeric. Any fractional part is
# discarded, truncating toward zero; every field read here is non-negative, so that is a floor.
j_num() {
  j_after "$1" "$2" || { _ret=-1; return; }
  local v=$_ret
  v=${v%%,*}
  v=${v%%\}*}
  v=${v%%[[:space:]]*}
  v=${v%%.*}
  case $v in
    '' | *[!0-9-]*) _ret=-1 ;;
    *) _ret=$v ;;
  esac
}

# $_u = the given Unicode codepoint encoded as UTF-8, built from \x byte escapes.
# printf's \uXXXX would be the obvious tool but it needs bash 4.2, and stock macOS ships only
# bash 3.2, so the bytes are computed here instead. Nothing else in this script requires 4.x.
j_utf8() {
  local cp=$1 h1 h2 h3 h4 fmt
  if [ "$cp" -lt 128 ]; then
    printf -v h1 '%02x' "$cp"
    fmt="\\x$h1"
  elif [ "$cp" -lt 2048 ]; then
    printf -v h1 '%02x' $((0xC0 | (cp >> 6)))
    printf -v h2 '%02x' $((0x80 | (cp & 0x3F)))
    fmt="\\x$h1\\x$h2"
  elif [ "$cp" -lt 65536 ]; then
    printf -v h1 '%02x' $((0xE0 | (cp >> 12)))
    printf -v h2 '%02x' $((0x80 | ((cp >> 6) & 0x3F)))
    printf -v h3 '%02x' $((0x80 | (cp & 0x3F)))
    fmt="\\x$h1\\x$h2\\x$h3"
  else
    printf -v h1 '%02x' $((0xF0 | (cp >> 18)))
    printf -v h2 '%02x' $((0x80 | ((cp >> 12) & 0x3F)))
    printf -v h3 '%02x' $((0x80 | ((cp >> 6) & 0x3F)))
    printf -v h4 '%02x' $((0x80 | (cp & 0x3F)))
    fmt="\\x$h1\\x$h2\\x$h3\\x$h4"
  fi
  printf -v _u "$fmt"
}

# $_ret = string value of "key" in $1, or "" when absent. Decodes JSON escapes, collapsing \n,
# \r and \t to a space so a multi-line value cannot break the single-line layout.
#
# Surrogate pairs are recombined into one codepoint: anything outside the BMP, emoji included,
# arrives as a high surrogate followed by a low one, and decoding them separately would produce
# two replacement characters instead of the intended glyph. An unpaired surrogate is not a
# character at all and is dropped. In practice Claude Code emits raw UTF-8 rather than \u
# escapes, so this path is a safety net rather than the common case.
j_str() {
  j_after "$1" "$2" || { _ret=''; return; }
  local r=$_ret n i=1 ch out='' hex lo cp lonum
  [ "${r:0:1}" = '"' ] || { _ret=''; return; }
  n=${#r}
  while [ "$i" -lt "$n" ]; do
    ch=${r:i:1}
    case $ch in
      '"') break ;;
      '\')
        i=$((i + 1))
        ch=${r:i:1}
        case $ch in
          n | r | t) out+=' ' ;;
          u)
            hex=${r:i+1:4}
            i=$((i + 4))
            if [[ $hex =~ ^[0-9a-fA-F]{4}$ ]]; then
              cp=$((16#$hex))
              if [ "$cp" -ge $((0xD800)) ] && [ "$cp" -le $((0xDBFF)) ]; then
                lo=${r:i+3:4}
                if [ "${r:i+1:2}" = '\u' ] && [[ $lo =~ ^[0-9a-fA-F]{4}$ ]]; then
                  lonum=$((16#$lo))
                  if [ "$lonum" -ge $((0xDC00)) ] && [ "$lonum" -le $((0xDFFF)) ]; then
                    i=$((i + 6))
                    j_utf8 $((0x10000 + (cp - 0xD800) * 0x400 + (lonum - 0xDC00)))
                    out+=$_u
                  fi
                fi
              elif [ "$cp" -ge $((0xDC00)) ] && [ "$cp" -le $((0xDFFF)) ]; then
                : # unpaired low surrogate; not a character
              else
                j_utf8 "$cp"
                out+=$_u
              fi
            fi
            ;;
          *) out+=$ch ;;
        esac
        ;;
      *) out+=$ch ;;
    esac
    i=$((i + 1))
  done
  _ret=$out
}

# $_ret = 1 when "key" in $1 is true, 0 when false or absent. Note an absent key and an explicit
# false are deliberately indistinguishable here: both mean "the mode is not on".
j_bool() {
  j_after "$1" "$2" || { _ret=0; return; }
  case $_ret in
    true*) _ret=1 ;;
    *) _ret=0 ;;
  esac
}

parse_payload() {
  local ws cw rl fh sd md th ef

  j_scope "$input" workspace && ws=$_ret || ws=''
  j_str "$ws" current_dir; cwd=$_ret
  [ -n "$cwd" ] || { j_str "$input" cwd; cwd=$_ret; }
  [ -n "$cwd" ] || cwd='.'

  j_str "$input" session_name; session_name=$_ret

  j_scope "$input" context_window && cw=$_ret || cw=''
  j_num "$cw" used_percentage;     ctx_pct=$_ret
  j_num "$cw" context_window_size; ctx_size=$_ret

  j_scope "$input" rate_limits && rl=$_ret || rl=''
  j_scope "$rl" five_hour && fh=$_ret || fh=''
  j_scope "$rl" seven_day && sd=$_ret || sd=''
  j_num "$fh" used_percentage; five_pct=$_ret
  j_num "$fh" resets_at;       five_reset=$_ret
  j_num "$sd" used_percentage; week_pct=$_ret
  j_num "$sd" resets_at;       week_reset=$_ret

  j_scope "$input" model && md=$_ret || md=''
  j_str "$md" display_name; model_name=$_ret
  [ -n "$model_name" ] || { j_str "$md" id; model_name=$_ret; }
  # "Opus 5 (1M context)" -> "Opus 5"; the real window size is appended separately when rendering.
  [[ $model_name =~ ^(.*[^[:space:]])[[:space:]]*\([^\)]*\)[[:space:]]*$ ]] && model_name=${BASH_REMATCH[1]}

  j_scope "$input" thinking && th=$_ret || th=""
  j_bool "$th" enabled; thinking_on=$_ret
  j_bool "$input" fast_mode; fast_on=$_ret

  j_scope "$input" effort && ef=$_ret || ef=""
  j_str "$ef" level; effort=$_ret
}

parse_payload

[[ $ctx_pct    =~ ^-?[0-9]+$ ]] || ctx_pct=-1
[[ $five_pct   =~ ^-?[0-9]+$ ]] || five_pct=-1
[[ $week_pct   =~ ^-?[0-9]+$ ]] || week_pct=-1
[[ $five_reset =~ ^-?[0-9]+$ ]] || five_reset=-1
[[ $week_reset =~ ^-?[0-9]+$ ]] || week_reset=-1
[[ $ctx_size   =~ ^-?[0-9]+$ ]] || ctx_size=-1

now=$(date +%s)

# Repo name and branch from a single git invocation: rev-parse accepts both queries at once and
# prints them on separate lines, so adding the branch costs no extra process. --abbrev-ref prints
# the literal "HEAD" when detached, in which case the short SHA is more useful.
# When git fails (not a work tree) both come back empty and the directory name stands in; that is
# what happens in a plain home directory, which is not a repo.
_git=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel --abbrev-ref HEAD 2>/dev/null)
repo=${_git%%$'\n'*}
branch=${_git##*$'\n'}
if [ -n "$repo" ] && [ "$repo" != "$branch" ]; then
  repo=$(basename "$repo")
  [ "$branch" = HEAD ] && branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
else
  repo=$(basename "$cwd")
  branch=''
fi
unset _git

# Context window size -> compact label: 1000000 -> 1M, 200000 -> 200k
fmt_window() {
  local s=$1
  [ "$s" -lt 1000 ] && return
  if [ $((s % 1000000)) -eq 0 ]; then
    printf '%dM' $((s / 1000000))
  else
    printf '%dk' $((s / 1000))
  fi
}

# Epoch seconds -> coarsest unit only: 5d, 4h, 47m, <1m, now, ?
countdown() {
  local target=$1 secs
  [ "$target" -lt 0 ] && { printf '%s' '?'; return; }
  secs=$((target - now))
  [ "$secs" -le 0 ] && { printf '%s' 'now'; return; }
  if [ "$secs" -ge 86400 ]; then
    printf '%dd' $((secs / 86400))
  elif [ "$secs" -ge 3600 ]; then
    printf '%dh' $((secs / 3600))
  elif [ "$secs" -ge 60 ]; then
    printf '%dm' $((secs / 60))
  else
    printf '%s' '<1m'
  fi
}

# pct -> filled cells at the current bar width, clamped, with a floor of one cell for any
# nonzero usage so low values stay visible.
cells() {
  local pct=$1 n
  [ "$pct" -lt 0 ] && pct=0
  n=$(((pct * bar + 50) / 100))
  [ "$n" -gt "$bar" ] && n=$bar
  [ "$pct" -gt 0 ] && [ "$n" -eq 0 ] && n=1
  printf '%s' "$n"
}

sev_fg() {
  local p=$1
  if [ "$p" -ge 80 ]; then printf '31'
  elif [ "$p" -ge 50 ]; then printf '33'
  else printf '32'; fi
}

sev_bg() {
  local p=$1
  if [ "$p" -ge 80 ]; then printf '101'
  elif [ "$p" -ge 50 ]; then printf '103'
  else printf '102'; fi
}

# The context bar is a standalone gauge with no second series to contrast against, so it
# stays bright independently of the intensities the usage bar's halves use.
sev_fg_bright() {
  local p=$1
  if [ "$p" -ge 80 ]; then printf '91'
  elif [ "$p" -ge 50 ]; then printf '93'
  else printf '92'; fi
}

rep() {
  local c=$1 n=$2 i out=""
  for ((i = 0; i < n; i++)); do out+="$c"; done
  printf '%s' "$out"
}

# Single series: full block, colored when filled, theme gray when not.
bar_single() {
  local pct=$1 n
  n=$(cells "$pct")
  printf '%s' "${ESC}[$(sev_fg_bright "$pct")m$(rep '█' "$n")${ESC}[${OFF_FG}m$(rep '█' $((bar - n)))${RESET}"
}

# Two series in one row. $1 = lower half, $2 = upper half.
# Emitted as three runs: both filled, one filled, neither.
bar_dual() {
  local ap=$1 bp=$2 a b lo hi out=""
  a=$(cells "$ap")
  b=$(cells "$bp")
  lo=$a; [ "$b" -lt "$lo" ] && lo=$b
  hi=$a; [ "$b" -gt "$hi" ] && hi=$b

  out+="${ESC}[$(sev_fg "$ap");$(sev_bg "$bp")m$(rep '▄' "$lo")"
  if [ "$a" -gt "$b" ]; then
    out+="${ESC}[$(sev_fg "$ap");${OFF_BG}m$(rep '▄' $((hi - lo)))"
  else
    out+="${ESC}[${OFF_FG};$(sev_bg "$bp")m$(rep '▄' $((hi - lo)))"
  fi
  out+="${ESC}[${OFF_FG};${OFF_BG}m$(rep '▄' $((bar - hi)))${RESET}"
  printf '%s' "$out"
}

# Precomputed pieces shared by every layout attempt.
win=$(fmt_window "$ctx_size")
t5=$(countdown "$five_reset")
t7=$(countdown "$week_reset")

# Effort as a fill gauge; an unrecognized or absent level shows nothing rather than guessing a
# position on the scale. Computed once here since it cannot change between layout attempts.
case $effort in
  low) eff_glyph=$GLYPH_EFFORT_LOW ;;
  medium) eff_glyph=$GLYPH_EFFORT_MED ;;
  high) eff_glyph=$GLYPH_EFFORT_HIGH ;;
  xhigh) eff_glyph=$GLYPH_EFFORT_XHIGH ;;
  max) eff_glyph=$GLYPH_EFFORT_MAX ;;
  *) eff_glyph='' ;;
esac

has_usage=0
if [ "$five_pct" -ge 0 ] || [ "$week_pct" -ge 0 ]; then
  has_usage=1
  f=$five_pct; [ "$f" -lt 0 ] && f=0
  w=$week_pct; [ "$w" -lt 0 ] && w=0
fi

has_timers=0
{ [ "$five_reset" -ge 0 ] || [ "$week_reset" -ge 0 ]; } && has_timers=1

# Columns Claude Code will not render into. COLUMNS is the pane width, but the status line is
# drawn into a narrower area and anything beyond it is silently clipped with an ellipsis.
# Measured with a column ruler in a 186-column pane: columns 181-182 rendered and a
# 184-column line was clipped, putting the usable width at 182 or 183. Reserving 4 fits either.
RESERVE=4

# Terminal width. COLUMNS is exported by Claude Code; tput is only a fallback for hosts that
# do not set it, and 80 is the conservative last resort (too narrow merely compacts the line,
# whereas guessing too wide would wrap it).
term_cols=""
[[ $COLUMNS =~ ^[0-9]+$ ]] && [ "$COLUMNS" -gt 0 ] && term_cols=$COLUMNS
if [ -z "$term_cols" ]; then
  probe=$(tput cols 2>/dev/null)
  [[ $probe =~ ^[0-9]+$ ]] && [ "$probe" -gt 0 ] && term_cols=$probe
fi
[ -z "$term_cols" ] && term_cols=80
budget=$((term_cols - RESERVE))
[ "$budget" -lt 1 ] && budget=1

# Current layout settings, degraded by LADDER below until the line fits.
bar=$BASE_BAR
name_max=$BASE_NAME
repo_max=0
branch_max=$BASE_BRANCH
show_flags=1
show_timers=1
show_window=1
show_model=1
show_labels=1
show_bars=1

# Builds OUT (with color) and PLAIN (a width-equivalent ASCII shadow) in one pass, so the
# measurement can never drift from what is actually printed. PLAIN substitutes ASCII for the
# multibyte glyphs, keeping ${#PLAIN} a true column count regardless of locale.
build() {
  local s r b fl
  r=$repo
  # repo_max of 0 means unlimited, which is the normal case.
  [ "$repo_max" -gt 0 ] && [ "${#r}" -gt "$repo_max" ] && r="${r:0:$((repo_max - 1))}…"
  OUT="${BOLD}${CYAN}${r}${RESET}"
  PLAIN="${r//…/.}"

  # Branch reads as part of the repo identity, so it is bound to the name by a SINGLE space
  # while every other segment is separated by two. That spacing is the grouping cue.
  if [ "$branch_max" -gt 0 ] && [ -n "$branch" ]; then
    b=$branch
    [ "${#b}" -gt "$branch_max" ] && b="${b:0:$((branch_max - 1))}…"
    OUT+=" ${DIM}(${RESET}${CYAN}${b}${RESET}${DIM})${RESET}"
    PLAIN+=" (${b//…/.})"
  fi

  if [ "$name_max" -gt 0 ] && [ -n "$session_name" ]; then
    s=$session_name
    [ "${#s}" -gt "$name_max" ] && s="${s:0:$((name_max - 1))}…"
    OUT+="  ${WHITE}${s}${RESET}"
    PLAIN+="  ${s//…/.}"
  fi

  # The effort gauge sits to the LEFT of the model, not the right: the circles and the mode
  # glyphs come from different Unicode blocks with different optical centers, so placing them
  # adjacent made them look vertically misaligned. The model name between them hides that.
  if [ "$show_model" -eq 1 ] && [ -n "$model_name" ]; then
    OUT+="  "
    PLAIN+="  "
    if [ -n "$eff_glyph" ]; then
      OUT+="${DIM}${eff_glyph}${RESET}  "
      PLAIN+="$eff_glyph  "
    fi
    OUT+="${MAGENTA}${model_name}"
    PLAIN+="${model_name}"
    if [ "$show_window" -eq 1 ] && [ -n "$win" ]; then
      OUT+=" ${win}"
      PLAIN+=" ${win}"
    fi
    OUT+="${RESET}"
  fi

  # Mode glyphs. Nothing is emitted when both modes are off, so the common case costs no width.
  # Separated by the normal two-space segment gap, matching the effort gauge on the model's other
  # side so the model sits evenly between them.
  if [ "$show_flags" -eq 1 ]; then
    fl=""
    [ "$thinking_on" -eq 1 ] && fl+="$GLYPH_THINK"
    [ "$fast_on" -eq 1 ] && fl+="$GLYPH_FAST"
    if [ -n "$fl" ]; then
      OUT+="  ${DIM}${fl}${RESET}"
      PLAIN+="  $fl"
    fi
  fi

  if [ "$ctx_pct" -ge 0 ]; then
    OUT+="  "; PLAIN+="  "
    if [ "$show_labels" -eq 1 ]; then
      OUT+="${DIM}ctx${RESET} "
      PLAIN+="ctx "
    fi
    if [ "$show_bars" -eq 1 ]; then
      OUT+="$(bar_single "$ctx_pct") "
      PLAIN+="$(rep '#' "$bar") "
    fi
    OUT+="${ctx_pct}%"
    PLAIN+="${ctx_pct}%"
  fi

  if [ "$has_usage" -eq 1 ]; then
    OUT+="  "; PLAIN+="  "
    if [ "$show_labels" -eq 1 ]; then
      OUT+="${DIM}5h/7d${RESET} "
      PLAIN+="5h/7d "
    fi
    # 5h on top (upper half), 7d on bottom; the label and the N%/N% suffix read
    # top-to-bottom in the same order.
    if [ "$show_bars" -eq 1 ]; then
      OUT+="$(bar_dual "$w" "$f") "
      PLAIN+="$(rep '#' "$bar") "
    fi
    OUT+="${f}%/${w}%"
    PLAIN+="${f}%/${w}%"
    if [ "$show_timers" -eq 1 ] && [ "$has_timers" -eq 1 ]; then
      OUT+=" ${DIM}↻${t5}/${t7}${RESET}"
      PLAIN+=" R${t5}/${t7}"
    fi
  fi
}

# Degradation sizes are expressed as a percentage of the base and floored at the minimum,
# rather than hardcoded. Hardcoded steps only shrink for one particular base: with literals
# tuned for a base of 20, setting BASE_BAR=6 would make the first "degradation" step raise
# the width to 16, and the fitting loop would then only stop overflowing by accident.
frac_bar() {
  local n=$(((BASE_BAR * $1 + 50) / 100))
  [ "$n" -lt "$MIN_BAR" ] && n=$MIN_BAR
  printf '%s' "$n"
}

frac_branch() {
  local n=$(((BASE_BRANCH * $1 + 50) / 100))
  [ "$n" -lt "$MIN_BRANCH" ] && n=$MIN_BRANCH
  printf "%s" "$n"
}

# Applied in order until the line fits. Ordered least-useful-first: the bars and the two
# percentages are the point of the line, so they are the last things to go. Steps that
# compute to the value already in effect are simply no-ops.
#
# The session name goes first and goes whole: Claude Code already prints it beside the input
# field, and at these widths that copy is only a line or two away, so a shrunken duplicate here
# earns less than the columns it costs. Every other element still degrades gradually.
LADDER=(
  "name_max=0"
  "bar=$(frac_bar 80)"
  "bar=$(frac_bar 60)"
  "show_timers=0"
  "branch_max=$(frac_branch 66)"
  "show_window=0"
  "bar=$(frac_bar 50)"
  "show_flags=0"
  "show_model=0"
  "branch_max=0"
  "bar=$(frac_bar 40)"
  "show_labels=0"
  "bar=$(frac_bar 30)"
  "bar=$(frac_bar 20)"
  "show_bars=0"
)

# Spend whatever budget is left over on the elastic elements. Done arithmetically rather than by
# stepping and rebuilding, since each build spawns a dozen subshells and this runs on every render.
# Each +1 of name_max adds one column until the name stops being truncated; each +1 of bar adds one
# column per bar on the line.
#
# $1 = 1 to let the session name grow too, allocated ahead of the bars so wide bars cannot starve
# it. It is 0 after a degradation pass: the name was dropped deliberately there, and handing it
# columns back would restore exactly what the ladder just decided the width could not afford.
grow() {
  local grow_name=$1 keep_bar=$bar keep_name=$name_max nbars=0 spare shown want gain add

  spare=$((budget - ${#PLAIN}))
  [ "$spare" -le 0 ] && return

  if [ "$grow_name" -eq 1 ] && [ -n "$session_name" ] && [ "$name_max" -lt "$MAX_NAME" ]; then
    shown=$name_max
    [ "${#session_name}" -lt "$shown" ] && shown=${#session_name}
    want=$MAX_NAME
    [ "${#session_name}" -lt "$want" ] && want=${#session_name}
    gain=$((want - shown))
    [ "$gain" -gt "$spare" ] && gain=$spare
    if [ "$gain" -gt 0 ]; then
      name_max=$((name_max + gain))
      spare=$((spare - gain))
    fi
  fi

  # Widening bars that are not being drawn would buy nothing, so they only count when shown.
  if [ "$show_bars" -eq 1 ]; then
    [ "$ctx_pct" -ge 0 ] && nbars=$((nbars + 1))
    [ "$has_usage" -eq 1 ] && nbars=$((nbars + 1))
  fi
  if [ "$nbars" -gt 0 ] && [ "$bar" -lt "$MAX_BAR" ]; then
    add=$((spare / nbars))
    [ $((bar + add)) -gt "$MAX_BAR" ] && add=$((MAX_BAR - bar))
    [ "$add" -gt 0 ] && bar=$((bar + add))
  fi

  if [ "$bar" -ne "$keep_bar" ] || [ "$name_max" -ne "$keep_name" ]; then
    build
    # Safety net: if the estimate overshot, fall back to the layout known to fit.
    if [ "${#PLAIN}" -gt "$budget" ]; then
      bar=$keep_bar
      name_max=$keep_name
      build
    fi
  fi
}

build

if [ "${#PLAIN}" -gt "$budget" ]; then
  # Too wide: degrade until it fits.
  step=0
  while [ "${#PLAIN}" -gt "$budget" ] && [ "$step" -lt "${#LADDER[@]}" ]; do
    eval "${LADDER[$step]}"
    step=$((step + 1))
    build
  done

  # The repo name is the one element the ladder cannot touch, so it survives every realistic
  # window. Only once the ladder is spent is it clipped, to exactly the overflow, since a long
  # repo name would otherwise overrun a narrow pane no matter what else was given up.
  if [ "${#PLAIN}" -gt "$budget" ]; then
    target=$((${#repo} - (${#PLAIN} - budget)))
    [ "$target" -lt "$MIN_REPO" ] && target=$MIN_REPO
    if [ "$target" -lt "${#repo}" ]; then
      repo_max=$target
      build
    fi
  fi

  # A ladder step overshoots whenever what it gave up was worth more columns than the overflow,
  # and dropping the session name whole overshoots by the width of the whole name. Give that slack
  # back to the bars rather than leaving the line short of the pane.
  grow 0
else
  grow 1
fi

printf '%s' "$OUT"
