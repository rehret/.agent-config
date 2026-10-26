#!/usr/bin/env bash
# Builds a dark preview page for the Mermaid diagrams in plan notes and design documents.
#
# Usage: render-preview.sh [-o out-dir] <file>...
#   A .mmd file is one diagram; any other file contributes every ```mermaid block it holds.
#   Writes <out-dir>/index.html (a new temp directory by default) and prints its path.
#   MERMAID_VERSION overrides the version found in Obsidian's app archive.
#
# The page loads Mermaid from jsdelivr, so the browser viewing it needs network access. Once all
# diagrams have run, <body data-rendered="yes"> is set, and a diagram that failed carries data-error.

set -euo pipefail

out=""
if [ "${1-}" = "-o" ]; then
  out=${2:?"-o needs a directory"}
  shift 2
fi
[ $# -gt 0 ] || { echo "usage: $(basename "$0") [-o out-dir] <file>..." >&2; exit 64; }
[ -n "$out" ] || out=$(mktemp -d "${TMPDIR:-/tmp}/mermaid-preview.XXXXXX")
mkdir -p "$out"

# Obsidian updates itself by downloading a newer app archive beside the installed one, so the
# newest archive is the one it runs. Each archive names its bundled Mermaid as mermaid@<version>.
find_obsidian_mermaid() {
  local archives=() f v
  while IFS= read -r f; do archives+=("$f"); done < <(
    ls -t "$HOME/Library/Application Support/obsidian/"obsidian-*.asar \
          "$HOME/.config/obsidian/"obsidian-*.asar 2>/dev/null || true)
  archives+=("/Applications/Obsidian.app/Contents/Resources/obsidian.asar")
  for f in "${archives[@]}"; do
    [ -f "$f" ] || continue
    v=$(LC_ALL=C grep -a -o -m1 -E 'mermaid@[0-9]+\.[0-9]+\.[0-9]+' "$f" | head -n 1 | cut -d@ -f2 || true)
    if [ -n "$v" ]; then echo "$v"; return; fi
  done
}

version=${MERMAID_VERSION:-$(find_obsidian_mermaid)}
[ -n "$version" ] || { echo "Obsidian's Mermaid version not found; set MERMAID_VERSION" >&2; exit 1; }

sections="$out/sections.tmp"
: > "$sections"
for f in "$@"; do
  [ -f "$f" ] || { echo "not a file: $f" >&2; exit 66; }
  case $f in
    *.mmd) mode=whole ;;
    *) mode=blocks ;;
  esac
  awk -v name="$(basename "$f")" -v mode="$mode" '
    function esc(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); return s }
    function open(title) { printf "<section><h2>%s</h2><pre class=\"mermaid\">\n", esc(title) }
    mode == "whole" && NR == 1 { open(name); on = 1 }
    mode == "blocks" && /^```mermaid[[:space:]]*$/ { n++; open(name ", diagram " n); on = 1; next }
    mode == "blocks" && on && /^```[[:space:]]*$/ { print "</pre></section>"; on = 0; next }
    on { print esc($0) }
    END { if (mode == "whole" && on) print "</pre></section>" }
  ' "$f" >> "$sections"
done

count=$(grep -c '<pre class="mermaid">' "$sections" || true)
[ "$count" -gt 0 ] || { rm -f "$sections"; echo "no mermaid diagrams found in: $*" >&2; exit 65; }

page="$out/index.html"
{
  cat <<'HEAD'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Mermaid Preview</title>
<style>
  :root { color-scheme: dark; }
  body { margin: 0; padding: 16px; background: #1e1e1e; color: #dcddde; font: 14px/1.5 -apple-system, system-ui, sans-serif; }
  .notes { display: grid; grid-template-columns: minmax(0, 700px); gap: 16px; }
  section { background: #262626; border: 1px solid #3a3a3a; border-radius: 6px; padding: 12px; }
  h2 { font-size: 14px; margin: 0 0 8px; }
  pre.mermaid { margin: 0; }
  pre.mermaid svg { max-width: 100%; height: auto; }
  p.error { color: #ff7b72; white-space: pre-wrap; }
</style>
</head>
<body>
<div class="notes">
HEAD
  cat "$sections"
  cat <<SCRIPT
</div>
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@${version}/dist/mermaid.esm.min.mjs';
  mermaid.initialize({ startOnLoad: false, theme: 'dark' });
  for (const el of document.querySelectorAll('pre.mermaid')) {
    try {
      await mermaid.run({ nodes: [el] });
    } catch (e) {
      el.dataset.error = String(e?.message ?? e);
      const p = document.createElement('p');
      p.className = 'error';
      p.textContent = el.dataset.error;
      el.after(p);
    }
  }
  document.body.dataset.rendered = 'yes';
</script>
</body>
</html>
SCRIPT
} > "$page"
rm -f "$sections"

echo "$page"
echo "$count diagram(s), Mermaid $version" >&2
