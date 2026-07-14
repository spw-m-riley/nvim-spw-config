# Plan 003: Preserve DataWeave file and executable context

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report - do not improvise. When done, update the status row for this plan in `plans/README.md` unless a reviewer tells you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5d80f88..HEAD -- lua/onebeer/mule/commands.lua lua/onebeer/mule/jobs/dataweave.lua lua/onebeer/mule/jobs/process.lua lua/onebeer/mule/config.lua lua/onebeer/mule/smoke.lua lua/onebeer/mule/fixtures/bin/dw-ok`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED - DataWeave CLI argument shape must be verified against the installed CLI or fixture contract before changing user commands.
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `5d80f88`, 2026-07-10, against the current uncommitted Mule workflow draft.

## Why this matters

DataWeave scripts often depend on their file path, project root, imports, and local resources. `:MuleDwValidate` runs a saved file path, but `:MuleDwRun` currently pipes buffer text to `dw run` with no path or project root. `:MuleDwRepl` also hardcodes `dw`, bypassing the configured executable seam used by the rest of the plugin and by smoke tests.

## Current state

- `lua/onebeer/mule/commands.lua` reads buffer text and runs DataWeave without a path:

```lua
79. local function current_buffer_text()
80.   return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
81. end
...
123. local function dw_run()
124.   local ok, result = require("onebeer.mule.jobs.dataweave").run_text(current_buffer_text())
125.   if ok then
126.     open_output("DataWeave Output", result.stdout or "")
```

- `lua/onebeer/mule/jobs/dataweave.lua` invokes `dw run` with stdin and no cwd:

```lua
48. ---@param text string
49. ---@return boolean, vim.SystemCompleted|string
50. function M.run_text(text)
...
56.   local result, run_err = process.run("dw", { "run" }, { stdin = text })
```

- `lua/onebeer/mule/commands.lua` hardcodes the REPL executable:

```lua
138. local function dw_repl()
139.   vim.cmd("botright split")
140.   vim.cmd("terminal dw repl")
141. end
```

- `lua/onebeer/mule/config.lua` already supports executable overrides:

```lua
14.   executables = {
15.     anypoint = "anypoint-cli-v4",
16.     dw = "dw",
```

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Format check | `stylua --check .` | exit 0 |
| Lint | `selene .` | exit 0 |
| DataWeave smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('dataweave-cli')" +qa` | exit 0 |

## Scope

**In scope**
- `lua/onebeer/mule/commands.lua`
- `lua/onebeer/mule/jobs/dataweave.lua`
- `lua/onebeer/mule/jobs/process.lua` only if command rendering for terminal use needs a small helper
- `lua/onebeer/mule/smoke.lua`
- `lua/onebeer/mule/fixtures/bin/dw-ok`
- `doc/onebeer.txt` and `docs/mule-workflow.html` only if command behavior text changes

**Out of scope**
- Implementing a DataWeave language server
- Storing DataWeave inputs or project secrets
- Reworking Maven/MUnit jobs

## Git workflow

- Branch: `advisor/003-preserve-dataweave-file-context`
- Commit message style: conventional commits, for example `fix: preserve dataweave file context`
- Do not push or open a PR unless explicitly instructed.

## Steps

### Step 1: Add a file-based run path

In `lua/onebeer/mule/jobs/dataweave.lua`, add `M.run_file(path)` that:

1. Uses `ensure_dw()`.
2. Detects the Mule project root with `onebeer.mule.detect.project(path)` when available.
3. Runs the configured `dw` executable with a file path argument, not anonymous stdin.
4. Sets `cwd` to the Mule project root when detected.
5. Preserves quickfix behavior on failure by passing `path` to `dataweave_parser.quickfix_items`.

Before choosing the exact argument shape, verify the installed DataWeave CLI supports it with `dw run --help` if available. If `dw` is not installed, use and document the fixture contract in the smoke test.

**Verify**: `stylua --check lua/onebeer/mule/jobs/dataweave.lua` -> exit 0.

### Step 2: Make `:MuleDwRun` use the current file

Update `dw_run()` in `lua/onebeer/mule/commands.lua` to mirror `dw_validate()`:

1. Require a named buffer.
2. Warn if the buffer has no path.
3. Call `require("onebeer.mule.jobs.dataweave").run_file(path)`.
4. Continue opening stdout in the scratch output window on success.

Keep `run_text` only if a smoke test or future API still needs it; otherwise remove it.

**Verify**: `stylua --check lua/onebeer/mule/commands.lua lua/onebeer/mule/jobs/dataweave.lua` -> exit 0.

### Step 3: Make the REPL use the configured executable

Update `dw_repl()` so it resolves `onebeer.mule.config.executable("dw")` instead of hardcoding `dw`. If the configured executable is a list, append `repl` to that list; if it is a string, run that executable with `repl`.

Use Neovim terminal APIs or a safely escaped `vim.cmd` command. Do not concatenate unescaped arbitrary strings into `:terminal`.

**Verify**: `stylua --check lua/onebeer/mule/commands.lua` -> exit 0.

### Step 4: Strengthen smoke coverage

Update `lua/onebeer/mule/fixtures/bin/dw-ok` so it can distinguish:

- `validate <path>`
- `run <path>`
- `repl`

Update `dataweave_cli()` in `lua/onebeer/mule/smoke.lua` to assert `run_file(dwl)` succeeds and that failures still populate quickfix with the DataWeave file path.

**Verify**: `nvim --headless "+lua require('onebeer.mule.smoke').run('dataweave-cli')" +qa` -> exit 0.

## Test plan

- Keep the fixture-based smoke stage as the authoritative test.
- Add at least one assertion that `run_file` passes the fixture `.dwl` path to the stub.
- Add at least one assertion that missing `dw` still returns `DataWeave CLI \`dw\` is not executable`.
- Run `stylua --check .` and `selene .`.

## Done criteria

- [ ] `:MuleDwRun` refuses unnamed buffers just like validation.
- [ ] DataWeave run uses a file path and project cwd when available.
- [ ] `:MuleDwRepl` uses the configured DataWeave executable instead of hardcoded `dw`.
- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('dataweave-cli')" +qa` exits 0.
- [ ] `stylua --check .` exits 0.
- [ ] `selene .` exits 0.
- [ ] No files outside the in-scope list are modified, except `plans/README.md` status if this plan is executed directly.

## STOP conditions

Stop and report if:

- The installed DataWeave CLI does not support running a file path and the fixture contract cannot represent the intended behavior.
- Correct support requires a larger DataWeave project model outside `lua/onebeer/mule/jobs/dataweave.lua`.
- Escaping the configured executable for terminal use cannot be done safely with stable Neovim APIs.

## Maintenance notes

Reviewers should focus on command construction. The fix should preserve the existing config-injected executable seam; do not replace it with raw `vim.fn.executable("dw")` calls in command handlers.
