# Plan 009: Add one aggregate Mule smoke gate

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the next
> step. If anything in the "STOP conditions" section occurs, stop and report;
> do not improvise. When done, update the status row for this plan in
> `plans/README.md` unless your dispatcher owns the index.
>
> **Drift check (run first)**:
> `rtk git status --short -- lua/onebeer/mule/smoke.lua README.md doc/onebeer.txt docs/mule-workflow.html`
> and
> `rtk git diff --stat 5d80f88 -- lua/onebeer/mule/smoke.lua README.md doc/onebeer.txt docs/mule-workflow.html`.
> This plan was written against an uncommitted Mule workflow draft. If any
> in-scope product file is still untracked, stop before creating an isolated
> worktree: the baseline implementation must be committed first. Otherwise,
> compare the "Current state" excerpts against live code and stop on a mismatch.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests / dx / docs
- **Planned at**: commit `5d80f88`, 2026-07-14, against the current uncommitted Mule workflow draft

## Why this matters

The Mule workflow has eleven passing fixture-backed smoke stages, but no single
repository command proves the complete surface. The developer docs also omit
the `commands` stage added by Plan 006, so following the documented validation
matrix can miss regressions in the actual `:Mule*` callbacks. A deterministic
`all` stage gives every later Mule change one reliable acceptance gate.

## Current state

- `lua/onebeer/mule/smoke.lua:878-891` defines the runnable stages, including
  `commands`, but exposes no ordered aggregate:

```lua
local stages = {
  commands = commands,
  foundation = foundation,
  ["dataweave-cli"] = dataweave_cli,
  ["dap-feasibility"] = dap_feasibility,
  ["apikit-navigation"] = apikit_navigation,
  ["anypoint-cli"] = anypoint_cli,
  harness = harness,
  ["harness-deliberate-fail"] = deliberate_fail,
  ["lemminx-catalog"] = lemminx_catalog,
  ["maven-build"] = maven_build,
  ["munit-runner"] = munit_runner,
  ["neotest-adapter"] = neotest_adapter,
}
```

- `lua/onebeer/mule/smoke.lua:895-913` runs only one named stage and defaults to
  `harness`.
- `doc/onebeer.txt:657-669` and
  `docs/mule-workflow.html:363-378` list individual stages but omit
  `commands`.
- All current non-deliberate stages passed together on 2026-07-14 when invoked
  from one `+lua` loop.
- The repository convention is to use one `+lua` loop when many headless stages
  run in one Neovim process; do not add one `+lua` argument per stage.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Aggregate Mule smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('all')" +qa` | exit 0 |
| Deliberate failure guard | `nvim --headless "+lua require('onebeer.mule.smoke').run('harness-deliberate-fail')" +qa` | non-zero exit |
| Lua lint | `selene .` | exit 0, zero findings |
| Format check | `stylua --check .` | exit 0 |
| Help tags | `nvim --headless "+helptags doc" +qa` | exit 0 |

## Scope

**In scope**:

- `lua/onebeer/mule/smoke.lua`
- `README.md`
- `doc/onebeer.txt`
- `doc/tags` when help tags are regenerated
- `docs/mule-workflow.html`
- `plans/README.md`

**Out of scope**:

- Changing product behavior in Mule commands, jobs, parsers, or integrations.
- Adding a new Lua test framework.
- Running the deliberate-failure stage as part of the aggregate success gate.
- Adding screenshots or validation recordings.

## Git workflow

- Branch: `advisor/009-add-aggregate-mule-smoke`
- Commit message: `test: add aggregate mule smoke gate`
- Do not push or open a PR unless explicitly instructed.
- Before branching, confirm the Mule baseline is committed; worktrees do not
  contain untracked source files.

## Steps

### Step 1: Define a deterministic success-stage order

In `lua/onebeer/mule/smoke.lua`, add an ordered list containing every normal
stage exactly once:

1. `harness`
2. `foundation`
3. `maven-build`
4. `munit-runner`
5. `dataweave-cli`
6. `lemminx-catalog`
7. `apikit-navigation`
8. `anypoint-cli`
9. `neotest-adapter`
10. `dap-feasibility`
11. `commands`

Keep `harness-deliberate-fail` in the stage map but exclude it from the success
list. Preserve explicit ordering instead of iterating `pairs(stages)`.

**Verify**: `stylua --check lua/onebeer/mule/smoke.lua` -> exit 0.

### Step 2: Implement `smoke.run("all")`

Refactor the runner so the error boundary is shared:

- A private helper runs one named stage and raises on an unknown name.
- `M.run("all")` executes the ordered success list in the current Neovim
  process.
- Any stage failure stops the aggregate immediately and preserves the existing
  headless `cquit` behavior.
- Individual stage names continue to work unchanged.
- `M.run()` without an argument continues to run only `harness`.
- Before advancing to the next stage, verify the completed stage restored any
  overridden globals and left no extra fixture window, buffer, scratch output,
  `target/`, or `.onebeer/` state. Fix leaks in the owning stage's existing
  `with_*`/cleanup boundary; do not make the aggregate runner silently erase
  unknown leaked state and report success.

Do not print success-shaped output for a skipped stage. If a stage is in the
ordered list, it must actually run.

**Verify**:
`nvim --headless "+lua require('onebeer.mule.smoke').run('all')" +qa`
-> exit 0.

### Step 3: Prove failure propagation and stage isolation

Keep `harness-deliberate-fail` directly runnable and confirm it still exits
non-zero. Add a bounded isolation assertion around the aggregate loop that
captures `vim.notify`, current windows/buffers, and known fixture artifact paths
before each stage and confirms the same baseline after that stage. After the
aggregate run, confirm no fixture scratch, `.onebeer/`, `target/`, or lockfile
churn remains.

**Verify**:

1. `nvim --headless "+lua require('onebeer.mule.smoke').run('harness-deliberate-fail')" +qa`
   -> non-zero exit with `deliberate smoke failure`.
2. `rtk git status --short` -> only intentional source, docs, and plan changes.

### Step 4: Make the aggregate gate canonical in docs

Update all three documentation surfaces:

- `doc/onebeer.txt`: show the `all` command first, retain the per-stage list for
  focused debugging, and add the missing `commands` stage.
- `docs/mule-workflow.html`: make `all` the primary copyable command and include
  `commands` in the focused-stage list.
- `README.md`: add one concise development-matrix row for the aggregate Mule
  smoke gate. Keep the root README high-level; detailed workflow guidance stays
  in the Mule help/HTML docs.

Regenerate `doc/tags`.

**Verify**:

1. `rg -n "smoke.*all|run\\('all'\\)|run\\('commands'\\)" README.md doc/onebeer.txt docs/mule-workflow.html`
   -> all three docs expose the aggregate gate and the detailed docs include
   `commands`.
2. `nvim --headless "+helptags doc" +qa` -> exit 0.

## Test plan

- The new `all` stage runs every existing non-deliberate stage.
- The deliberate failure remains excluded from `all` and still produces a
  non-zero process exit when selected directly.
- The aggregate run leaves no generated fixture output.
- Each stage restores overridden globals and editor/fixture state before the next
  stage begins.
- Existing individual stage invocations remain valid.

## Done criteria

- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('all')" +qa` exits 0.
- [ ] The aggregate list includes `commands` and every other normal stage once.
- [ ] `harness-deliberate-fail` is excluded from `all` and still exits non-zero.
- [ ] Aggregate execution detects stage-local global, window, buffer, and
      fixture-artifact leaks instead of carrying them into the next stage.
- [ ] `README.md`, `doc/onebeer.txt`, and `docs/mule-workflow.html` document the aggregate gate.
- [ ] `stylua --check .` exits 0.
- [ ] `selene .` exits 0.
- [ ] `nvim --headless "+helptags doc" +qa` exits 0.
- [ ] No generated fixture or lockfile changes remain.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

Stop and report if:

- The Mule baseline files are still untracked when an isolated worktree is
  about to be created.
- Any normal stage passes individually but fails in `all` because it leaks
  shared state that cannot be cleaned up locally.
- Supporting `all` would require changing product behavior instead of the smoke
  harness.
- The deliberate-failure stage cannot remain independently runnable.
- Any verification fails twice after a reasonable fix attempt.

## Maintenance notes

Every later Mule plan should use `smoke.run("all")` as its final regression
gate and retain smaller stage commands for fast iteration. New smoke stages
must be added to both the map and ordered success list unless they are
intentionally destructive or expected to fail.
