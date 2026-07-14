# Plan 007: Unify Mule executable resolution

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report; do not improvise. When done, update the status row for this plan in `plans/README.md` unless your dispatcher owns the index.
>
> **Drift check (run first)**: `git diff --stat 5d80f88..HEAD -- lua/onebeer/mule/config.lua lua/onebeer/mule/health.lua lua/onebeer/mule/integrations/neotest.lua lua/onebeer/mule/jobs lua/onebeer/mule/smoke.lua plans/README.md`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts below against live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug / dx
- **Planned at**: commit `5d80f88`, 2026-07-10

## Why this matters

The Mule config module already supports executable injection so smoke tests and users can route through wrapper scripts or pinned toolchains. Core job modules honor that seam, but Neotest and health still use raw executable names. This makes the workflow internally inconsistent: a command can work with configured `maven`, while Neotest runs `mvn` and health still reports `mvn` missing.

## Current state

- `lua/onebeer/mule/config.lua:14-20` defines configurable executables:

```lua
executables = {
  anypoint = "anypoint-cli-v4",
  dw = "dw",
  maven = "mvn",
}
```

- `lua/onebeer/mule/jobs/process.lua:24` routes job execution through `config.executable(executable_key)`.
- `lua/onebeer/mule/integrations/neotest.lua:19-24` hardcodes Maven:

```lua
command = {
  "mvn",
  "clean",
  "test",
  "-Dmunit.test=" .. munit.selector(test),
}
```

- `lua/onebeer/mule/health.lua:64-70` checks raw command names:

```lua
required("java", ...)
required("mvn", ...)
optional("dw", ...)
optional("anypoint-cli-v4", ...)
```

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Neotest smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('neotest-adapter')" +qa` | exit 0 |
| Health check | `nvim --headless "+checkhealth onebeer" +qa` | exit 0 |
| Lua lint | `selene .` | exit 0 |
| Format check | `stylua --check .` | exit 0 |

## Scope

**In scope**:
- `lua/onebeer/mule/config.lua`
- `lua/onebeer/mule/health.lua`
- `lua/onebeer/mule/integrations/neotest.lua`
- `lua/onebeer/mule/jobs/process.lua` only if a shared helper should replace duplicate command-vector logic
- `lua/onebeer/mule/jobs/dataweave.lua` and `lua/onebeer/mule/jobs/anypoint.lua` only for deduplicating existing `first_command` helpers
- `lua/onebeer/mule/smoke.lua`
- `doc/onebeer.txt` only if user-visible executable override behavior needs documentation
- `plans/README.md`

**Out of scope**:
- Changing default executable names.
- Installing tools.
- Changing non-Mule Neotest adapters.
- Adding a new package manager or tool resolver.

## Git workflow

- Branch suggestion: `advisor/007-mule-executable-resolution`.
- Commit message style: conventional commit, for example `fix: unify mule executable resolution`.
- Do not push or open a PR unless explicitly instructed.

## Steps

### Step 1: Centralize command-vector helpers

In `lua/onebeer/mule/config.lua`, add small helpers that preserve current behavior:

- `config.command(name, extra_args)` returns a fresh string array:
  - If `config.executable(name)` is a string, start with `{ executable }`.
  - If it is a string array, deep-copy it.
  - Append `extra_args` if provided.
  - Return `nil` if no executable is configured.
- `config.command_name(name)` or equivalent returns the first executable token for `vim.fn.executable` checks and display.

Then update duplicate local helpers in job modules only if the call sites become simpler. Do not broaden behavior beyond executable resolution.

**Verify**: `nvim --headless "+lua require('onebeer.mule.smoke').run('harness')" +qa` -> exit 0.

### Step 2: Use configured Maven in Neotest specs

Update `lua/onebeer/mule/integrations/neotest.lua` so `build_spec_for_test` uses the configured Maven command vector:

```lua
local command = config.command("maven", { "clean", "test", "-Dmunit.test=" .. munit.selector(test) })
```

If no Maven executable is configured, return `nil` from `build_spec` rather than falling back to raw `"mvn"`.

Update `neotest-adapter` smoke to set a non-default Maven executable via `config.with(...)` and assert the generated `spec.command` begins with that configured value while still containing the selector.

**Verify**: `nvim --headless "+lua require('onebeer.mule.smoke').run('neotest-adapter')" +qa` -> exit 0.

### Step 3: Make health honor configured executables

Update `lua/onebeer/mule/health.lua` so Maven, DataWeave, and Anypoint checks use `config.command_name(...)` instead of raw names. The health text should show both logical tool and configured command when useful, for example:

- ``Maven (`/path/to/mvn-wrapper`) is available``
- ``DataWeave CLI (`dw`) is optional...``

Keep `java`, `node`, and `npm` as raw environment checks unless there is already config support for them.

**Verify**: `nvim --headless "+checkhealth onebeer" +qa` -> exit 0, with no Lua errors.

## Test plan

- Strengthen `neotest-adapter` smoke to prove configured Maven reaches the run spec.
- Existing `harness`, `maven-build`, `dataweave-cli`, and `anypoint-cli` smoke stages should still pass with fixture executable injection.

## Done criteria

- [ ] No Mule module hardcodes `"mvn"` except default config/docs text.
- [ ] Neotest run specs use `config.executable("maven")` through a shared helper.
- [ ] Mule health checks report configured Maven, `dw`, and Anypoint command availability.
- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('neotest-adapter')" +qa` exits 0.
- [ ] `nvim --headless "+checkhealth onebeer" +qa` exits 0.
- [ ] `stylua --check .` exits 0.
- [ ] `selene .` exits 0.
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report if:

- Neotest requires the command field to be a shell string instead of a string array in this installed version.
- Health cannot be tested without depending on host-installed Mule tools.
- A correct fix would require changing the public config shape incompatibly.
- Any verification fails twice after a reasonable fix attempt.

## Maintenance notes

Keep executable resolution boring and centralized. Future Mule wrappers should not invent their own `first_command` or command-vector conversion unless the shared helper cannot support the shape.
