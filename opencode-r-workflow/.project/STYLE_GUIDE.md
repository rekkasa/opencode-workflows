# Project Style Guide

This document contains the strict coding style rules for this project. All AI agents MUST read and enforce these rules proactively whenever writing, editing, or generating code. Do not ask for permission to apply these rules.

---

## 1. R Coding Style

Apply these rules to all R code, including R chunks inside `.qmd` and `.Rmd` files. 

### 1.1 Pipe operator
- Use `|>` (native pipe). Never use `%>%`.
- Convert any existing `%>%` → `|>`.
- When `%>%` uses the `.` placeholder (e.g. `x %>% foo(arg, .)`), convert to the anonymous-function form: `x |> (\(.) foo(arg, .))()`.
- `|>` goes at the **end of the current line** (trailing), never the start of the next.
- Every `|>` continuation line is indented **2 spaces** from the assignment or function that opened the chain. Apply even inside function arguments.

### 1.2 Package loading and function calls
- Never use `library()` or `require()`. Remove any existing calls.
- Prefix every non-base function with `package::function()`.
- Base R packages (`base`, `stats`, `utils`, `methods`, `grDevices`, `graphics`, `datasets`) may be called without a prefix.
- Always use **named arguments** for every function call: `package::function(arg1 = value1, arg2 = value2)`.
- Put each argument on its **own line**, indented 2 spaces from the function name. The closing `)` goes on its own line, aligned with the opening call.
- *Exception:* Inside a pipe chain, the data argument is omitted (supplied by `|>`); all remaining arguments are still named and each on its own line.

### 1.3 Tidyverse over base R
Always prefer tidyverse equivalents. No exceptions.

| Instead of (base R)           | Use (tidyverse/tidy)                           |
|-------------------------------|------------------------------------------------|
| `lapply` / `sapply` / `apply` | `purrr::map*` family                           |
| `merge()`                     | `dplyr::left_join()` / `*_join()`              |
| `subset()`                    | `dplyr::filter()`                              |
| `paste()` / `paste0()`        | `stringr::str_c()`                             |
| `gsub()` / `sub()`            | `stringr::str_replace_all()` / `str_replace()` |
| `grep()` / `grepl()`          | `stringr::str_which()` / `str_detect()`        |
| `sprintf()`                   | `glue::glue()`                                 |
| `read.csv()`                  | `readr::read_csv()`                            |
| `write.csv()`                 | `readr::write_csv()`                           |
| `data.frame()`                | `tibble::tibble()`                             |
| `rbind()` / `cbind()`         | `dplyr::bind_rows()` / `bind_cols()`           |
| `Reduce()`                    | `purrr::reduce()`                              |
| `do.call()`                   | `rlang::exec()` or `purrr::reduce()`           |

### 1.4 Assignment
- Use `<-` for all variable assignment.
- Use `=` only inside function argument lists.

### 1.5 Naming
- All user-defined variables and functions must be `snake_case`. 
- No `camelCase`, no `dot.case`.

### 1.6 Strings
- Always use double quotes `"..."`. 
- Single quotes are only allowed when the string itself contains a double quote.

### 1.7 Booleans
- Spell out `TRUE` and `FALSE` in full. 
- Never use `T` or `F`.

### 1.8 Line length
- Maximum **80 characters** per line. 
- Break long lines using `|>` chains, multi-line argument lists, or intermediate assignments.

### 1.9 Oracle exception (test files only)
- Inside `tests/testthat/`, the **expected-value computation** of an assertion may use plain base R (`mean()`, `sum()`, explicit formulas, `[` indexing, `aggregate()`) instead of the tidyverse mappings in 1.3.
- Rationale: a test oracle should reach the same quantity by a *different route* than the implementation under test. If both are written with the same functions, a shared bug can pass silently.
- This exception covers **only** the `expected =` computation. Fixtures, scaffolding, and all other test code follow every other rule in this guide.
