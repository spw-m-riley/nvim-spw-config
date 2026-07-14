# Plan 011: Correct Mule Neotest run and debug semantics

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the next
> step. If anything in the "STOP conditions" section occurs, stop and report;
> do not improvise. When done, update the status row for this plan in
> `plans/README.md` unless your dispatcher owns the index.
>
> **Drift check (run first)**:
> `rtk git status --short -- lua/onebeer/mule/jobs/munit.lua lua/onebeer/mule/integrations/neotest.lua lua/onebeer/mule/integrations/dap.lua lua/onebeer/plugins/neotest.lua lua/onebeer/mule/smoke.lua lua/onebeer/mule/fixtures`
> and
> `rtk git diff --stat 5d80f88 -- lua/onebeer/mule/jobs/munit.lua lua/onebeer/mule/integrations/neotest.lua lua/onebeer/mule/integrations/dap.lua lua/onebeer/plugins/neotest.lua lua/onebeer/mule/smoke.lua lua/onebeer/mule/fixtures`.
> This plan was written against an uncommitted Mule workflow draft. Stop if the
> baseline remains untracked or the current excerpts have changed.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/009-add-aggregate-mule-smoke-gate.md`
- **Category**: bug / dx
- **Planned at**: commit `5d80f88`, 2026-07-14, against the current uncommitted Mule workflow draft

## Why this matters

The adapter now discovers MUnit positions, but it does not build commands from
the selected position correctly. Running the file root produces
`-Dmunit.test=nil#api-test.xml`, nested suite identity is flattened to a
basename, and the global Neotest DAP keymap still attempts a Mule debug run even
though the integration claims DAP is unsupported. The result is a summary that
looks integrated while file runs, nested suites, and debug behavior remain
incorrect.

## Current state

- `lua/onebeer/mule/integrations/neotest.lua:121-129` treats any tree data with
  `path` and `name` as a test:

```lua
local data = args and args.tree and args.tree:data() or nil
if data and data.path and data.name then
  return build_spec_for_test(data)
end
```

- A direct probe of the discovered file root on 2026-07-14 returned:

```lua
command = { "mvn", "clean", "test", "-Dmunit.test=nil#api-test.xml" }
```

- `lua/onebeer/mule/jobs/munit.lua:15-19` derives suite identity from only the
  file basename, even though discovery supports `src/test/munit/**/*.xml`.
- MuleSoft's current MUnit Maven documentation says `munit.test` is applied to
  the suite path relative to `src/test/munit`, and supports either
  `<suite-regex>` or `<suite-regex>#<test-regex>`:
  `https://docs.mulesoft.com/munit/latest/munit-maven-plugin#run-tests-using-the-plugin`.
- `lua/onebeer/mule/integrations/neotest.lua:47-53` reconstructs result paths as
  `project.munit_dir .. "/" .. result.classname .. ".xml"`, which assumes all
  suites are top-level.
- The current secondary Surefire smoke fixture maps to
  `src/test/munit/api-secondary-test.xml`, but no such source fixture exists;
  `lua/onebeer/mule/smoke.lua:850-860` accepts that fabricated ID.
- `lua/onebeer/plugins/neotest.lua:30-34` always runs nearest with
  `{ strategy = "dap" }`.
- `lua/onebeer/mule/integrations/neotest.lua:30-32` stores
  `strategy_supported = false` in context, but the installed Neotest source
  never reads that field. A DAP probe still returned a normal Maven command.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Neotest smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('neotest-adapter')" +qa` | exit 0 |
| DAP guard smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('dap-feasibility')" +qa` | exit 0 |
| Aggregate Mule smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('all')" +qa` | exit 0 |
| Lua lint | `selene .` | exit 0 |
| Format check | `stylua --check .` | exit 0 |

## Suggested executor toolkit

- Read the installed Neotest adapter interface and runner before changing
  `build_spec`; the current runtime passes the selected tree directly.
- Use the official MUnit Maven selector documentation linked above.
- Keep Maven invocation as an argument vector through
  `onebeer.mule.config.command`.

## Scope

**In scope**:

- `lua/onebeer/mule/jobs/munit.lua`
- `lua/onebeer/mule/integrations/neotest.lua`
- `lua/onebeer/mule/integrations/dap.lua`
- `lua/onebeer/plugins/neotest.lua`
- `lua/onebeer/mule/smoke.lua`
- `lua/onebeer/mule/fixtures/projects/basic-mule/src/test/munit/**`
- `lua/onebeer/mule/fixtures/surefire/**`
- `doc/onebeer.txt` only if the documented file/debug behavior changes
- `plans/README.md`

**Out of scope**:

- Implementing Mule JDWP support.
- Changing non-Mule Neotest adapters or keymaps.
- Running real Maven/MUnit in smoke tests.
- Replacing the fixture-backed Surefire parser with a new XML dependency.
- Making Neotest execution asynchronous; Neotest already owns its process.

## Git workflow

- Branch: `advisor/011-correct-mule-neotest-runs`
- Commit message: `fix: correct mule neotest run semantics`
- Do not push or open a PR unless explicitly instructed.
- Stop before worktree creation if the Mule baseline is uncommitted.

## Steps

### Step 1: Make MUnit suite identity project-relative

In `lua/onebeer/mule/jobs/munit.lua`:

- Replace basename-only suite derivation with a helper that detects the Mule
  project, computes the path relative to `project.munit_dir`, normalizes
  separators to `/`, and removes the final `.xml`.
- Preserve the existing basename fallback only when no project can be detected.
- Store this project-relative suite value on every discovered test.
- Keep `M.selector(test)` as `suite#name`.
- Add a public suite-selector helper for file-level runs rather than creating a
  fake test table.

Add a nested MUnit fixture so the expected suite identity is observable, for
example `nested/api-secondary-test`.

**Verify**:
`nvim --headless "+lua require('onebeer.mule.smoke').run('munit-runner')" +qa`
-> exit 0 with assertions for both top-level and nested suite selectors.

### Step 2: Build specs according to Neotest position type

Refactor `lua/onebeer/mule/integrations/neotest.lua` around a helper that accepts
`path` plus an optional selector:

- `type == "file"`: run that suite with
  `-Dmunit.test=<project-relative-suite>`.
- `type == "test"`: run the exact `suite#test` selector.
- Unknown or incomplete position data: return `nil` without manufacturing a
  selector.
- The fallback `args.file` path follows file-level behavior; it must not choose
  only the first discovered test.
- Continue using configured Maven command vectors and project cwd.

Remove the unused `context.strategy_supported` field.

**Verify**: Extend `neotest-adapter` smoke to assert:

- The file-root spec contains no `nil#`.
- The file-root selector targets `api-test`.
- The child-test selector remains `api-test#api-main-test`.
- A nested file-root spec uses its project-relative suite path.

Then run the stage -> exit 0.

### Step 3: Map Surefire results back to real discovered source paths

Replace direct path construction from `result.classname` with a lookup built
from discovered MUnit source files:

- Build a per-project map from project-relative suite identity to real source
  path.
- Match Surefire `classname` to that map.
- Produce result IDs using the exact source path and selector ID used by
  discovered positions.
- If a report cannot be mapped, use a selector-only fallback only when it
  cannot collide; otherwise omit it and return an explicit diagnostic from the
  smoke/helper path rather than inventing a nonexistent file.

Replace the fabricated secondary result assertion with a real nested MUnit
fixture whose discovered position and Surefire result share one ID.

**Verify**:
`nvim --headless "+lua require('onebeer.mule.smoke').run('neotest-adapter')" +qa`
-> exit 0 and every asserted result source path exists.

### Step 4: Fail closed for unsupported Mule DAP requests

Make the existing `<leader>td` keymap inspect the current file before invoking
Neotest DAP:

- Non-Mule tests keep current behavior.
- Mule MUnit files call a small public guard in the Mule DAP integration.
- The guard must require all of:
  - the explicit experimental global,
  - Java,
  - nvim-dap, and
  - a registered `java` adapter.
- When the guard fails, notify the exact reason and do not call
  `neotest.run.run`.

Also make the Mule adapter return no runnable DAP spec when
`args.strategy == "dap"` and the guard fails, so programmatic callers cannot
silently bypass the keymap guard.

Do not register or invent a Java adapter in this plan.

**Verify**:

1. `nvim --headless "+lua require('onebeer.mule.smoke').run('dap-feasibility')" +qa`
   -> exit 0 with assertions for the missing Java adapter reason.
2. `nvim --headless "+lua require('onebeer.mule.smoke').run('neotest-adapter')" +qa`
   -> exit 0 and a DAP build request returns no Maven run spec.

### Step 5: Keep user-facing help honest

If file-level behavior or DAP wording changes, update `doc/onebeer.txt` so:

- Neotest file runs are described as suite-scoped.
- Mule debug remains unavailable until the explicit JDWP prerequisites are
  real.

Regenerate help tags only when the help file changes.

**Verify**:
`rg -n "MUnit|Neotest|DAP|JDWP" doc/onebeer.txt`
-> wording matches implemented behavior.

## Test plan

- Top-level file run -> suite selector.
- Nested file run -> project-relative suite selector.
- Child test run -> suite plus test selector.
- Surefire result -> exact discovered source position ID.
- Duplicate test names in different suites -> no collision.
- Mule DAP keymap and direct adapter request -> fail closed without starting
  Maven.
- Non-Mule DAP behavior -> unchanged.

## Done criteria

- [ ] No file-level spec contains `nil#` or uses the filename as a test name.
- [ ] Suite identity is relative to `src/test/munit`, not basename-only.
- [ ] Nested suite results map to real discovered source paths.
- [ ] The Mule DAP guard requires a real `java` adapter and blocks unsupported runs.
- [ ] `strategy_supported` no longer appears in Mule or installed-contract assumptions.
- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('neotest-adapter')" +qa` exits 0.
- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('dap-feasibility')" +qa` exits 0.
- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('all')" +qa` exits 0.
- [ ] `stylua --check .` and `selene .` exit 0.
- [ ] No files outside scope are modified except plan-index status.

## STOP conditions

Stop and report if:

- The Mule baseline is not committed before isolated execution.
- Current MUnit reports use a `classname` shape that cannot be mapped to
  discovered suites without a real report fixture; capture the observed shape
  and revise the plan instead of guessing.
- Neotest requires a different file-position contract than the installed
  adapter interface shows.
- Blocking DAP requires changing global debug behavior for non-Mule tests.
- Correct nested-suite selection requires shell-string command construction.
- Any verification fails twice after a reasonable fix attempt.

## Maintenance notes

Reviewers must compare three identities end to end: discovered position ID,
Maven selector, and Surefire result key. They may share components but do not
have to be the same string. Never restore an ignored context flag as a substitute
for behavior enforced by Neotest or the keymap.
