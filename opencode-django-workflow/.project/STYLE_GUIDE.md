# Project Style Guide

This document contains the strict coding style rules for this project. All AI agents MUST read and enforce these rules proactively whenever writing, editing, or generating code. Do not ask for permission to apply these rules.

---

## 1. Python / Django Coding Style

Apply these rules to all Python code, including Django apps, management
commands, and any `.py` module in the project.

### 1.1 Formatting
- Format all code with **black** (default profile). Do not hand-format
  against black.
- Sort imports with **isort** (black-compatible profile) or `ruff`.
- Maximum **88 characters** per line (black's default). Break long lines
  with parentheses, not backslashes.
- Indent with **4 spaces**. Never tabs.

### 1.2 Imports and provenance
- Never use wildcard imports (`from module import *`). Remove any that exist.
- Import the module (`import json`) or explicit names
  (`from django.db import models`) — never `import *` and never rebind a
  name to something misleading.
- Group and order imports: standard library, then third-party, then local
  project imports, each group separated by a blank line.
- Use **absolute imports** for project modules
  (`from myapp.services import foo`); never implicit relative imports.
- Keep every name's origin obvious at the call site. Prefer
  `module.function()` or a clearly named import over an opaque alias.

### 1.3 Idiomatic Python / Django over hand-rolled equivalents
Always prefer the idiomatic construct. No exceptions.

| Instead of                                   | Use                                                  |
|----------------------------------------------|------------------------------------------------------|
| manual `for` loop building a list            | list/dict/set comprehension or generator             |
| `os.path.join` / `open(path)`                | `pathlib.Path`                                        |
| `"%s" % x` / `"{}".format(x)`                | f-strings                                             |
| `dict()` / `list()` with no args             | `{}` / `[]` literals                                  |
| raw SQL / `Model.objects.raw()`              | Django ORM querysets                                  |
| `Model.objects.filter(...)[0]`               | `.first()` / `.get()`                                |
| `len(queryset)` / `list(qs)` to count        | `queryset.count()` / `queryset.exists()`             |
| a query inside a loop (N+1)                  | `select_related()` / `prefetch_related()`            |
| `datetime.datetime.now()`                    | `django.utils.timezone.now()`                        |
| scattered `os.environ[...]`                  | a value read once in `settings`                      |
| hand-built HTTP/JSON responses              | `JsonResponse` / DRF serializers                     |
| `assert` for runtime validation             | explicit `raise` of a specific exception             |

### 1.4 Type hints
- Annotate every function signature: all parameters and the return type.
- Use modern syntax: `str | None`, `list[int]`, `dict[str, int]` — not
  `Optional`, `List`, `Dict` from `typing` unless targeting < 3.10.
- Annotate module-level constants and non-obvious attributes.

### 1.5 Naming
- Functions, variables, modules, and Django fields: `snake_case`.
- Classes (including Django models, forms, serializers): `PascalCase`.
- Constants: `UPPER_SNAKE_CASE`.
- No `camelCase` for functions or variables. No single-letter names except
  short-lived loop indices.

### 1.6 Strings
- Use **double quotes** `"..."` (black's normalization).
- Single quotes only when the string itself contains a double quote.
- Use f-strings for interpolation; never `%` or `str.format()`.

### 1.7 Booleans and None
- Spell out `True`, `False`, `None`.
- Compare to `None` with `is` / `is not`, never `==`.
- Test truthiness directly (`if items:`) rather than `if len(items) > 0:`.

### 1.8 Line length
- Maximum **88 characters** per line.
- Break long lines with parentheses, comprehensions, or intermediate
  assignments — never a trailing backslash.

### 1.9 Django conventions
- Models live in `models.py`; keep business logic in model methods or a
  dedicated `services.py`, not in views. Views stay thin.
- Never hand-write schema migrations — generate them with
  `manage.py makemigrations`. Data migrations may be written by hand.
- Read configuration through `settings`; never hardcode secrets or read
  `os.environ` deep inside application code.
- Querysets are lazy — build them up, evaluate once, and avoid evaluating
  the same queryset repeatedly.
- Every function and class carries a docstring (Google or NumPy style)
  stating purpose, args, returns, and raised exceptions.

### 1.10 Oracle exception (test files only)
- Inside `tests/`, the **expected-value computation** of an assertion may
  use plain Python (`math`, explicit formulas, manual `for` loops, list
  indexing, hand-built dicts/lists) instead of the idiomatic Django/ORM
  route in 1.3.
- Rationale: a test oracle should reach the same quantity by a *different
  route* than the implementation under test. If both are written with the
  same ORM query or the same helper, a shared bug can pass silently.
- This exception covers **only** the expected-value computation. Fixtures,
  factories, scaffolding, and all other test code follow every other rule
  in this guide.
