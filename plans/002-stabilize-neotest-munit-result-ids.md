# Plan 002: Stabilize MUnit Neotest result IDs

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report - do not improvise. When done, update the status row for this plan in `plans/README.md` unless a reviewer tells you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5d80f88..HEAD -- lua/onebeer/mule/integrations/neotest.lua lua/onebeer/mule/parsers/surefire.lua lua/onebeer/mule/smoke.lua lua/onebeer/mule/fixtures/surefire`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW - the change is local to result-key construction and smoke fixtures.
- **Depends on**: `plans/001-neotest-discover-munit-positions.md`
- **Category**: bug
- **Planned at**: commit `5d80f88`, 2026-07-10, against the current uncommitted Mule workflow draft.

## Why this matters

MUnit execution uses selectors like `suite#test`, but Neotest result mapping currently keys results by only the test name. Multiple MUnit suites can contain the same test name. When that happens, later Surefire results overwrite earlier ones and Neotest cannot reliably attach output/status to the position that was run.

## Current state

- `lua/onebeer/mule/integrations/neotest.lua` ignores `classname` when building result keys:

```lua
34. function M.result_map(report_paths)
35.   local results = {}
36.   for _, result in ipairs(surefire.parse_files(report_paths)) do
37.     results[result.name] = {
38.       errors = result.message and { { message = result.message } } or nil,
39.       status = result.status,
40.     }
41.   end
42.   return results
43. end
```

- `lua/onebeer/mule/parsers/surefire.lua` already returns both `classname` and `name`:

```lua
59.     results[#results + 1] = {
60.       classname = attr(attrs, "classname"),
61.       message = message,
62.       name = attr(attrs, "name"),
63.       status = status,
64.     }
```

- `lua/onebeer/mule/jobs/munit.lua` uses `suite#name` selectors:

```lua
76. function M.selector(test)
77.   return ("%s#%s"):format(test.suite, test.name)
78. end
```

- The current smoke test accidentally demonstrates overwrite behavior by parsing passed and failed reports with the same test name and expecting the final status to be failed:

```lua
384.   local results = neotest.result_map({
385.     fixture_path("surefire/TEST-passed.xml"),
386.     fixture_path("surefire/TEST-failed.xml"),
387.   })
388.   assert_equal("Neotest passed result", results["api-main-test"].status, "failed")
```

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Format check | `stylua --check .` | exit 0 |
| Lint | `selene .` | exit 0 |
| Mule smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('neotest-adapter')" +qa` | exit 0 |

## Scope

**In scope**
- `lua/onebeer/mule/integrations/neotest.lua`
- `lua/onebeer/mule/smoke.lua`
- `lua/onebeer/mule/fixtures/surefire/*.xml` if a second suite fixture is needed

**Out of scope**
- Changing Surefire parsing except to preserve already parsed fields
- Changing Maven/MUnit execution arguments
- Changing non-Mule Neotest adapters

## Git workflow

- Branch: `advisor/002-stabilize-neotest-munit-result-ids`
- Commit message style: conventional commits, for example `fix: key mule munit results by selector`
- Do not push or open a PR unless explicitly instructed.

## Steps

### Step 1: Centralize MUnit result IDs

In `lua/onebeer/mule/integrations/neotest.lua`, add a local helper that builds the same ID shape used by Plan 001 positions:

```lua
local function result_id(path, result)
  return ("%s::%s#%s"):format(path, result.classname, result.name)
end
```

If Plan 001 chose a different stable position ID shape, match that shape instead. The key requirement is that result IDs include both suite/classname and test name.

**Verify**: `stylua --check lua/onebeer/mule/integrations/neotest.lua` -> exit 0.

### Step 2: Pass report path context into result mapping

Update `M.result_map(report_paths)` so each parsed result key includes enough context to match Neotest positions. If Surefire report paths map one-to-one with suites, derive the MUnit XML path from the project or keep the key at `classname#name` only if Plan 001 used that same ID format. Do not leave keys as plain `result.name`.

**Verify**: `nvim --headless "+lua require('onebeer.mule.smoke').run('neotest-adapter')" +qa` -> the smoke may fail until Step 3 updates assertions, but it must not error before reaching the changed assertion.

### Step 3: Add a collision fixture/assertion

Update the `neotest_adapter()` smoke assertions so they prove two results with the same `name` and different `classname` do not overwrite each other. Use fixture XML files if needed.

Minimum assertions:

- `results["api-test#api-main-test"]` or the Plan 001 equivalent key exists
- a second suite key can coexist with the same test name
- no assertion expects the failed result to overwrite the passed result

**Verify**: `nvim --headless "+lua require('onebeer.mule.smoke').run('neotest-adapter')" +qa` -> exit 0.

## Test plan

- Use fixture Surefire reports only; do not require a real Maven/MUnit run.
- Keep the smoke stage deterministic and independent of report file ordering.
- Run `stylua --check .` and `selene .`.

## Done criteria

- [ ] `M.result_map` no longer keys results by only `result.name`.
- [ ] Smoke coverage proves same-name tests from different suites do not collide.
- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('neotest-adapter')" +qa` exits 0.
- [ ] `stylua --check .` exits 0.
- [ ] `selene .` exits 0.
- [ ] No files outside the in-scope list are modified, except `plans/README.md` status if this plan is executed directly.

## STOP conditions

Stop and report if:

- Plan 001 has not landed or did not define a stable position ID shape.
- Neotest requires result keys that cannot be derived from Surefire `classname` and `name`.
- The fix requires parsing real MUnit report formats not represented by the current fixtures.

## Maintenance notes

Reviewers should compare the final result key shape with the position IDs returned by `discover_positions`. The two must match exactly or Neotest status will still appear missing.
