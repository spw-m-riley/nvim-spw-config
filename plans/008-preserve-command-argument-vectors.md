# Plan 008: Preserve command argument vectors

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report; do not improvise. When done, update the status row for this plan in `plans/README.md` unless your dispatcher owns the index.
>
> **Drift check (run first)**: `git diff --stat 5d80f88..HEAD -- lua/onebeer/mule/commands.lua lua/onebeer/mule/jobs/anypoint.lua lua/onebeer/mule/smoke.lua docs/mule-workflow.html doc/onebeer.txt plans/README.md`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts below against live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: `plans/006-add-command-callback-smoke.md`
- **Category**: bug / dx
- **Planned at**: commit `5d80f88`, 2026-07-10

## Why this matters

Maven and Anypoint CLI commands often need quoted values, spaces, and flag forms that are not safe to reconstruct by splitting the raw command string. Neovim already provides parsed user-command arguments as `ctx.fargs`; the Mule commands should use that vector instead of re-splitting `ctx.args`. `:MuleStatus` should also recognize common JSON flag forms so JSON output is displayed as structured data instead of raw text.

## Current state

- `lua/onebeer/mule/commands.lua:8-14` splits Maven args manually:

```lua
local function build(ctx)
  local args = vim.split(vim.trim(ctx.args), "%s+", { trimempty = true })
  local ok, result = require("onebeer.mule.jobs.maven").build({
    args = #args > 0 and args or nil,
    quickfix = true,
  })
```

- `lua/onebeer/mule/commands.lua:178-185` does the same for Anypoint args and only detects a standalone `--output` token:

```lua
local args = vim.split(vim.trim(ctx.args), "%s+", { trimempty = true })
...
local ok, result = require("onebeer.mule.jobs.anypoint").run(args, { json = vim.tbl_contains(args, "--output") })
```

- `docs/mule-workflow.html:350` documents `:MuleStatus runtime-mgr:application:describe my-app --output json`, but `--output=json` is also a common CLI shape and currently falls through as raw text.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Command smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('commands')" +qa` | exit 0 |
| Anypoint smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('anypoint-cli')" +qa` | exit 0 |
| Lua lint | `selene .` | exit 0 |
| Format check | `stylua --check .` | exit 0 |
| Help tags | `nvim --headless "+helptags doc" +qa` | exit 0 if docs changed |

## Scope

**In scope**:
- `lua/onebeer/mule/commands.lua`
- `lua/onebeer/mule/jobs/anypoint.lua` only if JSON flag detection belongs closer to the job wrapper
- `lua/onebeer/mule/smoke.lua`
- `docs/mule-workflow.html` and `doc/onebeer.txt` only for documenting supported argument forms
- `plans/README.md`

**Out of scope**:
- Implementing a shell parser.
- Changing Maven or Anypoint CLI semantics.
- Adding destructive Anypoint deploy wrappers.
- Supporting secrets in command arguments.

## Git workflow

- Branch suggestion: `advisor/008-mule-command-args`.
- Commit message style: conventional commit, for example `fix: preserve mule command argument vectors`.
- Do not push or open a PR unless explicitly instructed.

## Steps

### Step 1: Use `ctx.fargs` for argument vectors

In `lua/onebeer/mule/commands.lua`, replace manual `vim.split(vim.trim(ctx.args), "%s+", ...)` for user command arguments with a helper like:

```lua
local function command_args(ctx)
  return ctx.fargs or {}
end
```

Use it for:

- `MuleBuild`
- `MuleStatus`

Do not change `MuleTest` selector handling unless you intentionally support spaces inside selectors. Current selectors are expected to be a single Maven `suite#test` value.

**Verify**: `stylua --check lua/onebeer/mule/commands.lua` -> exit 0.

### Step 2: Detect JSON output forms explicitly

Add a small helper for Anypoint JSON output detection. It should return true for:

- `--output json`
- `--output=json`
- `-o json` if Anypoint CLI supports that alias in current docs or observed behavior

It should return false for:

- `--output text`
- no output flag

Pass `{ json = wants_json(args) }` to `anypoint.run`.

If you choose to put this helper in `jobs/anypoint.lua`, expose it only if smoke tests need direct access; otherwise keep it private in `commands.lua`.

**Verify**: `nvim --headless "+lua require('onebeer.mule.smoke').run('anypoint-cli')" +qa` -> exit 0.

### Step 3: Add command smoke assertions for quoted args and `--output=json`

Extend the `commands` smoke stage from plan 006:

- Invoke `:MuleBuild -DskipTests -Dexample='value with spaces'` using a form that Neovim parses into `ctx.fargs`.
- Assert the Maven stub received one argument containing `value with spaces`, not three split pieces.
- Invoke `:MuleStatus runtime-mgr:application:describe demo --output=json`.
- Assert the Anypoint command opens structured inspected output, not the raw JSON string path.

If the existing fixture stubs do not expose received args, add the smallest fixture stub behavior needed to record args under a cleaned fixture scratch path.

**Verify**: `nvim --headless "+lua require('onebeer.mule.smoke').run('commands')" +qa` -> exit 0.

### Step 4: Update docs only if behavior is user-visible

If you add support for `--output=json`, update `docs/mule-workflow.html` and `doc/onebeer.txt` to show both `--output json` and `--output=json` as supported. Keep the docs concise.

**Verify**: `nvim --headless "+helptags doc" +qa` -> exit 0 if `doc/onebeer.txt` changed.

## Test plan

- Command smoke covers the regression: quoted arguments remain a single argument.
- Anypoint smoke covers JSON parser behavior independent of command callbacks.

## Done criteria

- [ ] `MuleBuild` and `MuleStatus` use `ctx.fargs` rather than manual whitespace splitting.
- [ ] `:MuleStatus ... --output=json` requests JSON parsing.
- [ ] Quoted command arguments are preserved in the command smoke stage.
- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('commands')" +qa` exits 0.
- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('anypoint-cli')" +qa` exits 0.
- [ ] `stylua --check .` exits 0.
- [ ] `selene .` exits 0.
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report if:

- Neovim's `ctx.fargs` does not preserve quoted args in this installed runtime.
- Fixture stubs would need to write outside fixture scratch paths to expose received args.
- Correct handling appears to require a full shell parser.
- Any verification fails twice after a reasonable fix attempt.

## Maintenance notes

Keep command callbacks vector-oriented. Do not reconstruct shell command strings for Maven, DataWeave, or Anypoint; all current job wrappers accept argument arrays.
