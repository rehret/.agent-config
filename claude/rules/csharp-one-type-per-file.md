---
paths:
  - "**/*.cs"
---

# One type per file (C#)

This applies to C# only; other languages follow their repository's conventions.

Each type gets a file of its own, named after it: `InvoiceLine.cs` holds `InvoiceLine`. A type is any class, record, struct, interface, enum or delegate, however small; a one-line record or a two-member enum still gets its own file. The rule limits types per file, not files per type, so a partial type split across files is fine.

Exceptions:

- **Nested types**, declared inside the type that owns them, such as a test fixture's private fakes.
- **Helper types used only by the file's main type**, such as a private record holding intermediate state, or a C# `file`-scoped type. A helper qualifies while no other production code names it; once another type uses it, it moves to its own file. Tests don't count: a test naming a helper is no reason to move it, since tests should not shape the code's structure.
- **Types so tightly bound that any reference to one must also reference the other** may share a file, though splitting them is fine too. This is rare: types that are merely related, or often used together, do not qualify.

When a case seems to call for another exception, ask me rather than deciding. In existing code that breaks the rule, don't split files I didn't ask you to touch; mention them instead.
