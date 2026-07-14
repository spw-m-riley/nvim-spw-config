# Plan 013: Harden Mule output and file-write boundaries

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the next
> step. If anything in the "STOP conditions" section occurs, stop and report;
> do not improvise. When done, update the status row for this plan in
> `plans/README.md` unless your dispatcher owns the index.
>
> **Drift check (run first)**:
> `rtk git status --short -- lua/onebeer/mule/catalog.lua lua/onebeer/mule/jobs/anypoint.lua lua/onebeer/mule/commands.lua lua/onebeer/mule/smoke.lua lua/onebeer/mule/fixtures`
> and
> `rtk git diff --stat 5d80f88 -- lua/onebeer/mule/catalog.lua lua/onebeer/mule/jobs/anypoint.lua lua/onebeer/mule/commands.lua lua/onebeer/mule/smoke.lua lua/onebeer/mule/fixtures`.
> This plan was written against an uncommitted Mule workflow draft. Stop if the
> baseline remains untracked or the current excerpts have changed.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: `plans/009-add-aggregate-mule-smoke-gate.md`
- **Category**: bug
- **Planned at**: commit `5d80f88`, 2026-07-14, against the current uncommitted Mule workflow draft

## Why this matters

Two boundary values currently escape otherwise careful command error handling.
Valid JSON `null` from Anypoint decodes to `vim.NIL`, reaches a string-only
output helper, and crashes the user command. Catalog filesystem failures can
throw from `mkdir` or be ignored by `writefile`, even though `generate`
advertises a `path|nil, error|nil` return contract. Both should become
actionable notifications backed by deterministic smoke coverage.

## Current state

- `lua/onebeer/mule/jobs/anypoint.lua:64-68` returns any successfully decoded
  JSON value:

```lua
local ok, decoded = pcall(vim.json.decode, result.stdout or "")
if ok then
  return true, decoded
end
```

- `lua/onebeer/mule/commands.lua:230-237` renders tables with `vim.inspect` and
  sends every other value directly to `open_output`.
- `lua/onebeer/mule/commands.lua:120-121` requires a string:

```lua
local function open_output(title_text, output)
  local lines = vim.split(output ~= "" and output or "(no output)", "\n", { plain = true })
```

- A live probe on 2026-07-14 with JSON `null` failed with
  `expected string, got userdata`.
- `lua/onebeer/mule/catalog.lua:72-88` ignores `mkdir` and `writefile` failure
  results.
- `lua/onebeer/mule/catalog.lua:95-109` returns a catalog path immediately after
  `M.write(...)`.
- A live probe using a file where the output directory should be caused
  `Vim:E739` to escape the `generate` return contract.
- Existing smoke fixtures cover successful JSON objects and catalog writes, not
  scalar/null JSON or filesystem failure.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Anypoint smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('anypoint-cli')" +qa` | exit 0 |
| Catalog smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('lemminx-catalog')" +qa` | exit 0 |
| Command smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('commands')" +qa` | exit 0 |
| Aggregate Mule smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('all')" +qa` | exit 0 |
| Lua lint | `selene .` | exit 0 |
| Format check | `stylua --check .` | exit 0 |

## Scope

**In scope**:

- `lua/onebeer/mule/catalog.lua`
- `lua/onebeer/mule/jobs/anypoint.lua` only if decoded-value normalization
  belongs at the job boundary
- `lua/onebeer/mule/commands.lua`
- `lua/onebeer/mule/smoke.lua`
- `lua/onebeer/mule/fixtures/bin/**`
- `doc/onebeer.txt` and `docs/mule-workflow.html` only if troubleshooting text
  changes
- `plans/README.md`

**Out of scope**:

- Changing Anypoint authentication or command semantics.
- Rejecting successful plain-text fallback when JSON parsing was requested.
- Atomic catalog locking across concurrent Neovim instances.
- Changing catalog discovery or LemMinX settings.
- Generalizing OneBeer's unrelated float helpers.

## Git workflow

- Branch: `advisor/013-harden-mule-command-boundaries`
- Commit message: `fix: harden mule command boundaries`
- Do not push or open a PR unless explicitly instructed.
- Stop before worktree creation if the Mule baseline is uncommitted.

## Steps

### Step 1: Make catalog writes return explicit results

Before changing the return type, run
`rg -n "catalog\\.(write|generate)" lua/onebeer/mule` and account for every
caller. Update direct `catalog.write` smoke callers to assert the new success
result; do not leave callers silently ignoring a failed write.

Change `catalog.write(output, mappings)` to return
`boolean, string|nil`:

- Validate or create the parent directory.
- Convert `vim.fn.mkdir` errors and a missing parent directory into a clear
  error string.
- Call `vim.fn.writefile` through a narrow protected boundary and check its
  numeric result.
- Return `false, <actionable message>` on failure and `true, nil` on success.
- Include the destination path in the message, but never include file content.

Update `catalog.generate` to propagate a write error as `nil, err` and return
the path only after a confirmed successful write.

Do not add a broad catch around the entire command.

**Verify**:
`stylua --check lua/onebeer/mule/catalog.lua`
-> exit 0.

### Step 2: Cover an unwritable catalog destination deterministically

In the `lemminx-catalog` smoke stage:

- Create a regular file at a fixture scratch path.
- Request a catalog underneath that file as though it were a directory.
- Assert `catalog.generate` returns `nil` plus a message containing the output
  path.
- Assert no catalog is created.
- Clean the blocker file in all paths.

Extend the command smoke so `:MuleGenerateCatalog` reports the same failure as a
notification without a Lua stack trace. Add the smallest command test seam
needed to supply a failing output path; do not change the public command
signature solely for testing.

**Verify**:
`nvim --headless "+lua require('onebeer.mule.smoke').run('lemminx-catalog')" +qa`
-> exit 0.

### Step 3: Normalize all output-window values

In `lua/onebeer/mule/commands.lua`, add one private renderer:

- strings -> unchanged
- `vim.NIL` -> `null`
- numbers and booleans -> `tostring(value)`
- tables -> `vim.inspect(value)`
- `nil` or empty string -> `(no output)`

Make `open_output` accept the rendered string only. Route DataWeave and
Anypoint output through the renderer so future decoded scalar values cannot
reach `vim.split` directly.

Do not use an unsafe cast or silently replace unknown userdata with success
text; return a clear unsupported-output error if the value is neither a known
JSON scalar nor a table/string.

**Verify**:
`stylua --check lua/onebeer/mule/commands.lua`
-> exit 0.

### Step 4: Add JSON scalar and null fixtures

Add fixture executables or fixture modes for valid JSON:

- `null`
- a boolean
- a number
- the existing object result

Extend `anypoint-cli` smoke to prove decoding succeeds for each value. Extend
the `commands` stage to invoke `:MuleStatus --output=json` for `null` and at
least one scalar, assert an output window opens, and assert no command callback
error occurs.

Keep the existing plain-text fallback assertion.

**Verify**:

1. `nvim --headless "+lua require('onebeer.mule.smoke').run('anypoint-cli')" +qa`
   -> exit 0.
2. `nvim --headless "+lua require('onebeer.mule.smoke').run('commands')" +qa`
   -> exit 0.

## Test plan

- Successful catalog write.
- Empty mapping refusal.
- Parent path blocked by a regular file.
- JSON object, null, boolean, and numeric output rendering.
- Plain-text fallback after requested JSON remains successful.
- Command callbacks convert all failures to notifications without stack traces.

## Done criteria

- [ ] `catalog.write` and `catalog.generate` return explicit filesystem errors.
- [ ] Every `catalog.write` and `catalog.generate` caller handles or explicitly
      asserts the new result contract.
- [ ] No failed catalog write reports a success path.
- [ ] JSON `null` renders as `null` without a Lua error.
- [ ] Numeric and boolean JSON values render without a Lua error.
- [ ] Existing object and plain-text output behavior remains intact.
- [ ] `lemminx-catalog`, `anypoint-cli`, `commands`, and `all` smoke stages exit 0.
- [ ] `stylua --check .` and `selene .` exit 0.
- [ ] No generated fixture output remains.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

Stop and report if:

- The Mule baseline is not committed before isolated execution.
- Filesystem failure cannot be reproduced inside fixture scratch paths without
  changing host permissions.
- The fix requires swallowing unknown output types instead of reporting them.
- Correct handling changes the intentional plain-text fallback after JSON
  decode failure.
- Any verification fails twice after a reasonable fix attempt.

## Maintenance notes

Treat decoded JSON and filesystem APIs as typed boundaries. Future command
output should go through the renderer, and future catalog mutations should
return explicit success/error values before any user notification claims
completion. Plan 010 must build on this `generate_catalog()` failure branch
rather than replacing it when adding the LemMinX refresh.
