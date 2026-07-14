# Plan 006: Add command-callback smoke coverage

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report; do not improvise. When done, update the status row for this plan in `plans/README.md` unless your dispatcher owns the index.
>
> **Drift check (run first)**: `git diff --stat 5d80f88..HEAD -- lua/onebeer/mule/commands.lua lua/onebeer/mule/smoke.lua lua/onebeer/mule/fixtures plans/README.md`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts below against live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/005-make-catalog-generation-honest.md`
- **Category**: tests / dx
- **Planned at**: commit `5d80f88`, 2026-07-10

## Why this matters

The existing smoke suite proves core job modules, parsers, and integrations. It does not exercise the editor-facing `:Mule*` commands that users actually run. That gap already hid the empty-catalog command behavior and can also hide argument parsing, buffer-name, notification, and scratch-window regressions.

## Current state

- `lua/onebeer/mule/commands.lua` registers the command surface:

```lua
-- lua/onebeer/mule/commands.lua:201-227
create_command("MuleBuild", build, { nargs = "*" })
create_command("MuleTest", test, { nargs = "?" })
create_command("MuleTestNearest", test_nearest, ...)
create_command("MuleDwValidate", dw_validate, ...)
create_command("MuleDwRun", dw_run, ...)
create_command("MuleDwRepl", dw_repl, ...)
create_command("MuleGenerateCatalog", generate_catalog, ...)
create_command("MuleStatus", anypoint_status, { nargs = "*" })
```

- `lua/onebeer/mule/smoke.lua:490-502` lists smoke stages, but none invoke `require("onebeer.mule.commands").setup()` or run `:MuleBuild`, `:MuleTest`, `:MuleDwRun`, `:MuleGenerateCatalog`, or `:MuleStatus`.
- `plans/README.md:16-17` previously deferred this coverage after the first improvement pass.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| New command smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('commands')" +qa` | exit 0 |
| Existing Mule smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('maven-build')" "+lua require('onebeer.mule.smoke').run('munit-runner')" "+lua require('onebeer.mule.smoke').run('dataweave-cli')" "+lua require('onebeer.mule.smoke').run('anypoint-cli')" +qa` | exit 0 |
| Lua lint | `selene .` | exit 0 |
| Format check | `stylua --check .` | exit 0 |

## Scope

**In scope**:
- `lua/onebeer/mule/smoke.lua`
- `lua/onebeer/mule/commands.lua` only for tiny testability seams if required
- `lua/onebeer/mule/fixtures/**` only for command-specific fixture output
- `plans/README.md`

**Out of scope**:
- Changing the command UX beyond what is required to make it testable.
- Adding a separate Lua test framework.
- Editing non-Mule OneBeer command surfaces.

## Git workflow

- Branch suggestion: `advisor/006-mule-command-smoke`.
- Commit message style: conventional commit, for example `test: add mule command smoke coverage`.
- Do not push or open a PR unless explicitly instructed.

## Steps

### Step 1: Add smoke helpers for command execution

In `lua/onebeer/mule/smoke.lua`, add helpers that make command assertions deterministic:

- A `with_notifications(fn)` helper that temporarily replaces `vim.notify`, records `{ message, level, title }`, restores the original function in all paths, and returns captured notifications.
- A buffer helper that opens a fixture Mule XML or `.dwl` file and restores/deletes buffers after the assertion.
- An output-window cleanup helper for commands such as `:MuleDwRun` and `:MuleStatus` that open scratch windows.
- Reuse `config.with(...)` so command runs use fixture executables and do not depend on host Maven, `dw`, or Anypoint CLI.

Keep these helpers private to `smoke.lua`.

**Verify**: `stylua --check lua/onebeer/mule/smoke.lua` -> exit 0.

### Step 2: Add a `commands` smoke stage

Register a new stage in `smoke.lua`:

```lua
["commands"] = commands,
```

The stage should run in a fresh headless Neovim process and call `require("onebeer.mule.commands").setup()` before invoking commands. It must assert all of these editor-facing paths:

- `:MuleBuild` from a Mule XML fixture runs the configured Maven stub and reports completion.
- `:MuleTest` from a Mule XML or MUnit fixture runs the configured Maven stub and reports completion.
- `:MuleTestNearest` from inside the fixture `<munit:test>` uses the expected selector.
- `:MuleDwValidate` and `:MuleDwRun` from a named `.dwl` fixture use configured `dw` stubs; `:MuleDwRun` opens inspectable output and does not error in headless mode.
- `:MuleGenerateCatalog` follows plan 005 behavior: it either writes a non-empty catalog for a fixture with local XSD mappings or warns without writing an empty catalog for an empty fixture.
- `:MuleStatus runtime-mgr:application:describe demo --output json` uses the configured Anypoint stub and opens output.
- Negative path: one command from outside a Mule project warns clearly instead of throwing a stack trace.

**Verify**: `nvim --headless "+lua require('onebeer.mule.smoke').run('commands')" +qa` -> exit 0.

### Step 3: Keep smoke stages isolated

Make sure the command stage cleans up:

- Any generated `.onebeer/` catalog fixture output.
- `target/` or report files created by stubs.
- Scratch buffers and windows created by output commands.
- Temporary notification overrides.

Do not let this stage change `nvim-pack-lock.json` or repository-local generated files outside fixture scratch paths.

**Verify**: `rtk git status --short` -> only intentional source/fixture/plan changes are listed.

## Test plan

- New smoke stage: `commands`.
- Existing smoke stages should continue to pass because command helpers must not alter shared config permanently.

## Done criteria

- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('commands')" +qa` exits 0.
- [ ] Existing `maven-build`, `munit-runner`, `dataweave-cli`, and `anypoint-cli` smoke stages still exit 0.
- [ ] `stylua --check .` exits 0.
- [ ] `selene .` exits 0.
- [ ] `rtk git status --short` shows no generated fixture output.
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report if:

- Headless Neovim cannot safely exercise output-window commands without changing product behavior.
- Running `commands.setup()` in smoke conflicts with already-registered commands and cannot be made isolated.
- The command stage requires real Maven, `dw`, Anypoint CLI, or network access.
- Any verification fails twice after a reasonable fix attempt.

## Maintenance notes

Future command changes should extend this stage first. The goal is not exhaustive UI testing; it is a fast guard that proves user commands route to the already-tested job layers with the right buffer, cwd, executable, and argument context.
