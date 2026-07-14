# Plan 001: Discover MUnit positions in Neotest

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report - do not improvise. When done, update the status row for this plan in `plans/README.md` unless a reviewer tells you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5d80f88..HEAD -- lua/onebeer/mule/integrations/neotest.lua lua/onebeer/mule/jobs/munit.lua lua/onebeer/mule/smoke.lua lua/onebeer/plugins/neotest.lua`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED - Neotest adapter contracts are strict, and bad IDs can break nearest/file runs.
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `5d80f88`, 2026-07-10, against the current uncommitted Mule workflow draft.

## Why this matters

The Mule adapter is registered with Neotest, but it currently returns no positions. Neotest interprets `nil` from `discover_positions` as "No positions found", which means the summary, file runs, nearest-test runs, watch mode, and status UI cannot reliably target MUnit tests. The standalone `:MuleTestNearest` command is useful, but the Neotest integration is not complete until test positions exist.

## Current state

- `lua/onebeer/plugins/neotest.lua` registers the Mule adapter in the shared Neotest setup:

```lua
92.         require("onebeer.mule.integrations.neotest").adapter(),
94.       discovery = {
95.         enabled = false,
96.       },
```

- `lua/onebeer/mule/integrations/neotest.lua` currently has an empty discovery implementation:

```lua
56.       local path = args and args.file or vim.api.nvim_buf_get_name(0)
57.       local tests = munit.discover_file(path)
58.       return tests[1] and build_spec_for_test(tests[1]) or nil
59.     end,
60.     discover_positions = function(_)
61.       return nil
62.     end,
```

- `lua/onebeer/mule/jobs/munit.lua` already parses MUnit XML test names and line numbers:

```lua
29.   local tests = {}
30.   for line_number, line in ipairs(lines) do
31.     for name in line:gmatch("<munit:test%s+[^>]-name=[\"']([^\"']+)") do
32.       tests[#tests + 1] = {
33.         line = line_number,
34.         name = name,
35.         path = path,
36.         suite = suite_name(path),
```

- Neotest provides `neotest.lib.positions.parse_tree(positions, opts)` for turning a flat position list into a `neotest.Tree`.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Format check | `stylua --check .` | exit 0 |
| Lint | `selene .` | exit 0 |
| Mule smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('neotest-adapter')" +qa` | exit 0 |

If a headless command creates a literal `$XDG_CONFIG_HOME/` directory in the repo root, remove that generated directory before finishing.

## Scope

**In scope**
- `lua/onebeer/mule/integrations/neotest.lua`
- `lua/onebeer/mule/smoke.lua`
- `lua/onebeer/mule/fixtures/projects/basic-mule/src/test/munit/api-test.xml` only if more fixture tests are needed

**Out of scope**
- Non-Mule Neotest adapters
- DAP strategy behavior
- Maven/MUnit command semantics outside Neotest position discovery

## Git workflow

- Branch: `advisor/001-neotest-discover-munit-positions`
- Commit message style: conventional commits, for example `fix: discover mule munit neotest positions`
- Do not push or open a PR unless explicitly instructed.

## Steps

### Step 1: Add MUnit position construction

In `lua/onebeer/mule/integrations/neotest.lua`, add a helper that turns `munit.discover_file(path)` results into Neotest positions.

Use a file root position plus one child test position per `<munit:test>`. Use stable IDs based on the MUnit selector shape, such as:

- file position: `path`
- test position: `path .. "::" .. munit.selector(test)`

Use 0-based Neotest ranges. A single-line test can use `{ test.line - 1, 0, test.line - 1, 0 }`.

**Verify**: `stylua --check lua/onebeer/mule/integrations/neotest.lua` -> exit 0.

### Step 2: Implement `discover_positions`

Replace the `discover_positions = function(_) return nil end` stub with a function that:

1. Refuses non-MUnit files via the existing `is_munit_file(path)` guard.
2. Returns `nil` only when the file is not a Mule MUnit file or contains no tests.
3. Returns a `neotest.Tree` using `require("neotest.lib.positions").parse_tree`.

Keep the adapter shape compatible with existing `build_spec` and `results`.

**Verify**: `stylua --check lua/onebeer/mule/integrations/neotest.lua` -> exit 0.

### Step 3: Strengthen the smoke test

Update `lua/onebeer/mule/smoke.lua` stage `neotest_adapter()` so it calls `adapter.discover_positions(munit_xml)` and asserts:

- the returned tree is not `nil`
- the root data path is the fixture MUnit XML path
- at least one child has name `api-main-test`
- the child ID includes `api-test#api-main-test`

**Verify**: `nvim --headless "+lua require('onebeer.mule.smoke').run('neotest-adapter')" +qa` -> exit 0.

## Test plan

- Extend the existing smoke stage rather than adding a separate test framework.
- Keep the single fixture minimum, but make the assertions prove Neotest discovery returns a tree with a runnable MUnit test.
- Run `stylua --check .` and `selene .`.

## Done criteria

- [ ] `adapter.discover_positions(munit_xml)` returns a non-`nil` Neotest tree for the fixture file.
- [ ] The discovered test position uses a stable selector-based ID.
- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('neotest-adapter')" +qa` exits 0.
- [ ] `stylua --check .` exits 0.
- [ ] `selene .` exits 0.
- [ ] No files outside the in-scope list are modified, except `plans/README.md` status if this plan is executed directly.

## STOP conditions

Stop and report if:

- `lua/onebeer/mule/integrations/neotest.lua` no longer contains the `discover_positions` stub shown above.
- The installed Neotest API does not expose `neotest.lib.positions.parse_tree` or an equivalent tree builder.
- A working implementation requires changing global Neotest config or other adapters.

## Maintenance notes

Plan 002 depends on the position ID shape introduced here. If you choose a different ID format, update Plan 002 before it is executed.
