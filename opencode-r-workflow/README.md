# R Development with Opencode

Personal opencode setup for structured R development, using
custom agents and skills to drive a pipeline from planning
through implementation to tested code.

## Quick Start

```bash
git clone <this-repo>
cd opencode-r-project
ln -s ~/my-skills/.config/opencode/skills/r-style ~/.config/opencode/skills/r-style
ln -s ~/my-skills/.config/opencode/skills/code-implementation-plan ~/.config/opencode/skills/code-implementation-plan
ln -s ~/my-skills/.config/opencode/skills/generate-objectives ~/.config/opencode/skills/objectives
ln -s ~/my-skills/.config/opencode/skills/grill-me ~/.config/opencode/skills/grill-me
```

## How This Works

The workflow runs as **two separate sessions**, so that the
interview transcript never weighs down the orchestration context.

```
Session 1:  opencode --agent interviewer
            grill -> .project/OBJECTIVES.md (+ ARCHITECTURE.md), then stop

Session 2:  opencode                        (project-manager is default)
            architect -> r-developer -> tester -> archive objectives
```

`.project/OBJECTIVES.md` is the only thing that crosses between
them. It carries a `Status: active` header; the project manager
flips it to `completed` and moves it to `.project/ARCHIVE/` when
the feature is done, so "no active objectives" stays detectable.

Start the interviewer directly whenever you know you are beginning
a new objective — it handles whatever state the objectives file is
in. If you start the project manager by mistake, its Phase 0 check
redirects you rather than improvising objectives.

The pipeline turns a natural-language description into a
grilled-down specification, an implementation plan, working R
code, and a test suite, all following the conventions in
`.project/STYLE_GUIDE.md`.

See `CHANGES.md` for the full rationale behind the current
structure, including the prompt-caching setup in `opencode.jsonc`.

## Prerequisites

- [Opencode CLI](https://opencode.ai) (latest)
- R >= 4.3
- R packages: tidyverse, devtools, testthat, roxygen2

## Installation

1. **Clone the repository**

   ```bash
   git clone <this-repo> opencode-r-project
   cd opencode-r-project
   ```

2. **Symlink skills**

   The four skills live in `~/my-skills/.config/opencode/skills/`.
   Symlink them into the active opencode skills directory:

   ```bash
   mkdir -p ~/.config/opencode/skills
   ln -s ~/my-skills/.config/opencode/skills/r-style \
     ~/.config/opencode/skills/r-style
   ln -s ~/my-skills/.config/opencode/skills/code-implementation-plan \
     ~/.config/opencode/skills/code-implementation-plan
   ln -s ~/my-skills/.config/opencode/skills/generate-objectives \
     ~/.config/opencode/skills/objectives
   ln -s ~/my-skills/.config/opencode/skills/grill-me \
     ~/.config/opencode/skills/grill-me
   ```

   Note: `r-developer` and `tester` no longer load the `r-style`
   skill — the rules are inlined in their prompts so they cost no
   extra round trip. The symlink is still worth keeping for ad-hoc
   R work outside the pipeline.

## Project Structure

```
.
├── opencode.jsonc                  Entry point (sets default_agent)
├── .project/
│   ├── STYLE_GUIDE.md              R coding conventions (canonical)
│   ├── .gitignore                  Ignores ARCHITECTURE.md
│   ├── OBJECTIVES.md               [runtime] Feature spec
│   ├── ARCHITECTURE.md             [runtime] Module-level design decisions
│   ├── TASKS/                      [runtime] Per-task implementation plans
│   └── ISSUES.md                   [runtime] Blocker log
└── .opencode/
    ├── agents/
    │   ├── interviewer.md          Scope definer (primary agent)
    │   ├── project-manager.md      Orchestrator (primary, default)
    │   ├── architect.md            Systems architect subagent
    │   ├── r-developer.md          Implementation engineer subagent
    │   └── tester.md               Test engineer subagent
    └── .gitignore                  [gitignored]
```

## Agent Pipeline

The workflow is a fixed linear pipeline split across two
sessions. The project manager offers two run modes at startup:
**step-by-step** (approve every handoff) or **autopilot** (approve
the plan once, then run straight through, stopping only for real
decisions).

### Session 1 — Interviewer

`interviewer` grills you relentlessly, one question at a time,
until every branch of the design tree is resolved. Coding style
questions are never asked — `.project/STYLE_GUIDE.md` is treated
as settled law.

The result is synthesized into `.project/OBJECTIVES.md` (feature
spec, stamped `Status: active`) and, if it does not yet exist,
`.project/ARCHITECTURE.md`. Then the session ends. The interviewer
has the subagent dispatcher disabled, so it cannot start the
pipeline itself.

### Session 2 — Project Manager

`project-manager` (the default agent) reads the objectives cold,
confirms the active feature with you, and drives the rest.

#### Architect

The `architect` subagent is dispatched to read OBJECTIVES.md and
write `.project/TASKS/<task>.md`. The output includes typed
function signatures, pseudocode, a file layout, data flow, and an
execution checklist split into `[IMPL]` and `[TEST]` items.

#### R Developer

The `r-developer` subagent executes only `[IMPL]` checklist items.
The style rules are inlined in its prompt, so it reads only the
task file. It runs smoke tests via `source()` on every modified
file, and must never touch `tests/testthat/`. When re-invoked to
fix code bugs it reads only the `## Code Bug Fixes` section, the
named failing tests, and the named `R/` files.

#### Tester

The `tester` subagent writes `[TEST]` items, executes them with
`testthat::test_file()`, runs the full suite as a regression gate,
and classifies failures as test bugs (self-fixed, up to 3
attempts) or code bugs (escalated back to the R Developer). The
fix loop between R Developer and Tester runs up to 3 cycles. On
exhaustion, the deadlock is logged to `.project/ISSUES.md`.

#### Close-out

When you confirm the feature is done, `OBJECTIVES.md` is flipped
to `Status: completed` and moved to `.project/ARCHIVE/`, along
with `ISSUES.md` if its entries are resolved.

## How Testing Works

Developer and tester run on the same model, so their mistakes can
correlate: a model that misremembers, say, which denominator
`sd()` uses would write code with that bug *and* a test expecting
the same wrong number. Green checkmark, bug ships. Every test's
weak point is its **oracle** — wherever the expected value came
from — so the pipeline builds tests in three tiers, ordered by how
contamination-resistant that source is:

**Tier 1 — Properties and metamorphic relations (written first).**
Assertions with no computed expected value at all: row counts
preserved, results within documented bounds, invariance under row
shuffling, spread unchanged by adding a constant, group means
between group min and max, errors raised where the spec says so.
Nothing was computed, so no misconception can hide in the
expectation. These catch implementation slips (NA handling, join
duplication, order dependence) cheaply.

**Tier 2 — Exact values anchored on the plan's Worked Examples.**
The architect (a *different model* from the developer/tester pair)
must include 1–2 tiny hand-derived input → output examples per
exported function in Module Specs. The tester turns them into
assertions verbatim, never recomputing them. Exact-value checks
are thereby anchored on a second head — this is what catches
shared *conceptual* errors, which sail through Tier 1.

**Tier 3 — Exact values with an independent-path oracle.** For
cases beyond the examples, the tester computes `expected =` via
plain base R and explicit formulas — a deliberately different
route from the tidyverse implementation (see §1.9 of
`STYLE_GUIDE.md` for this carve-out). Both routes would need the
same bug to agree wrongly.

The tester may never assert an exact value from its own unaided
arithmetic; if a value can't be grounded in Tier 2 or 3, it writes
a Tier 1 property instead.

**When the anchors disagree**, the disagreement is surfaced, not
smoothed over. If a Worked-Example test fails, the tester
recomputes the value independently and takes a three-way vote:
recomputation + spec vs. code → ordinary code bug; recomputation +
code vs. spec → the *example* is suspect, logged under
`Spec Example Conflicts`, and the project manager halts (even in
autopilot) for a human ruling rather than entering the fix loop.
Two models disagreeing loudly is the system working; the failure
mode this design exists to prevent is them agreeing quietly on the
same mistake.

### Domain Boundaries

- R Developer: reads test files but must never create or modify
  them
- Tester: reads implementation files but must never modify them
- Interviewer: talks to you, writes objectives, dispatches nothing
- Project Manager: dispatches subagents, writes no code or tests

## Skills

Skills are loaded from `~/.config/opencode/skills/` on demand when
their trigger phrases match.

| Skill | Role |
|---|---|
| `grill-me` | Interviews relentlessly until the plan is fully specified |
| `objectives` | Captures shared understanding into `.project/OBJECTIVES.md` |
| `code-implementation-plan` | Turns OBJECTIVES.md into `.project/TASKS/<task>.md` |
| `r-style` | Enforces R code conventions on all `.R`, `.qmd`, and `.Rmd` files |

> **Sync note:** the R style rules now live in three places:
> `.project/STYLE_GUIDE.md` (canonical, for humans), the `r-style`
> skill (for ad-hoc R work outside the pipeline), and inlined in
> `r-developer.md` and `tester.md` (so the pipeline agents pay no
> round trip to fetch them). When conventions change, update all
> three. See `CHANGES.md` for why.

## Workspace Lifecycle

### Starting a New R Project

1. Copy this opencode config into the project (or keep this repo
   as a standalone setup and reference it).
2. Ensure skills are symlinked into `~/.config/opencode/skills/`.
3. Run `opencode --agent interviewer` in the project directory.

### Working Through a Feature

1. `opencode --agent interviewer` — grill session, objectives
   written, session ends.
2. `opencode` — the project manager confirms the feature, asks for
   a run mode, and dispatches the architect.
3. Approve the plan. The R Developer implements it.
4. The Tester writes and verifies tests, with up to 3 fix cycles.
5. Confirm the feature is done — objectives are archived
   automatically.

### Resetting After a Feature

Handled for you. On close-out the project manager archives
`OBJECTIVES.md` (and `ISSUES.md`) into `.project/ARCHIVE/`. Clear
`.project/TASKS/` of completed task files yourself when it gets
cluttered.

`.project/ARCHITECTURE.md` persists across features. The project
manager revises it in place after each task when new modules or
structural changes are introduced, keeping it under ~100 lines —
it is read on every planning run, so it is not allowed to grow
without bound.

## Falling Back Off opencode-go

When opencode-go's usage window runs out, the whole pipeline can
be temporarily switched to your personal API keys — same agents,
same prompts, same workflow, different backends — without
touching any files. When Go quota resets, going back is equally
trivial.

The fallback routes by model family, not by "everything to one
provider":

- **DeepSeek-family models** (interviewer, project-manager,
  r-developer, tester) go direct to `api.deepseek.com` with your
  DeepSeek API key. Direct is much cheaper than routing DeepSeek
  through a gateway.
- **Everything else** (currently only the architect on GLM) goes
  through OpenRouter, which gives GLM without needing yet another
  provider account, plus OpenRouter's own provider-failover for
  free.

If you later move some agents to Kimi or Qwen, extend the same
pattern — add each new family as its own provider if you have a
direct key, or leave it under OpenRouter if you don't.

### One-time setup

1. Set both API keys in your shell:
   ```sh
   export DEEPSEEK_API_KEY=sk-...
   export OPENROUTER_API_KEY=sk-or-...
   ```
   Put these in `~/.zshrc` / `~/.bashrc` so they persist.

2. Look up the current OpenRouter model IDs (they change) and
   edit `.opencode/profiles/fallback-overlay.json` to match:
   ```sh
   opencode models openrouter --refresh
   ```
   Only the OpenRouter entries need verification. The DeepSeek
   ID (`deepseek/deepseek-v4-pro`) is stable and already matches
   the `models` block registered in `opencode.jsonc`.

3. Optionally alias the wrapper globally so you can call it from
   anywhere:
   ```sh
   alias opencode-fallback='/path/to/opencode-r-project/scripts/opencode-fallback'
   ```

### Using it

- **Normal mode (opencode-go):** `opencode` — nothing changes.
- **Fallback mode:** `./scripts/opencode-fallback` (or the alias).
  Every agent uses its fallback model for that session; DeepSeek
  goes direct, GLM goes through OpenRouter.

The switch happens per invocation. Close the session, run
`opencode` again, and you're back on Go — no cleanup, no file
edits.

### Mid-session fallback

If you hit the Go limit *during* a running session, you don't have
to restart:

- Press `Tab` (or use `/agent`) to move between agents in the TUI.
- Use `/models` to pick a fallback model for the currently
  selected agent for the rest of this session.

That's manual per agent, but it recovers a session in flight
without losing context. For the next session, use the wrapper.

### How it works

The wrapper reads `.opencode/profiles/fallback-overlay.json` and
passes it through the `OPENCODE_CONFIG_CONTENT` environment
variable, which sits at the highest user-controllable tier of
opencode's config precedence — above the project `opencode.jsonc`
and above the `.opencode` directory that holds the agent files.
Because opencode *merges* configs rather than replacing them,
only the `model:` field of each agent gets overridden; every
prompt, tool permission, cache setting, and skill still comes
from the usual files. No third-party plugins, no filesystem
swaps.

The `opencode-go`, `deepseek`, and `openrouter` provider blocks
all live in `opencode.jsonc` and are registered whenever opencode
starts. Which of the three actually gets called depends on which
provider prefix each agent's active model ID resolves to.

## Modifying This Setup

### Adding a Skill

1. Create a `SKILL.md` in
   `~/my-skills/.config/opencode/skills/<name>/`.
2. Symlink it into `~/.config/opencode/skills/<name>`.
3. Reload opencode — skills are auto-discovered.

### Changing the Default Agent

Edit `opencode.jsonc` and change the `"default_agent"` value.

### Updating the Style Guide

1. Edit `.project/STYLE_GUIDE.md` (canonical).
2. Mirror the changes in
   `~/.config/opencode/skills/r-style/SKILL.md` (runtime copy).

### Adding an R Package

Add it to the Prerequisites section. Agents use
`package::function()` prefixes throughout, so no `library()`
calls are needed in any code produced by this setup.
