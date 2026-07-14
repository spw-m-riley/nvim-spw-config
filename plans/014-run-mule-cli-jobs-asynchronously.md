# Plan 014: Run editor-facing Mule CLI jobs asynchronously

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the next
> step. If anything in the "STOP conditions" section occurs, stop and report;
> do not improvise. When done, update the status row for this plan in
> `plans/README.md` unless your dispatcher owns the index.
>
> **Drift check (run first)**:
> `rtk git status --short -- lua/onebeer/mule/jobs lua/onebeer/mule/commands.lua lua/onebeer/mule/smoke.lua lua/onebeer/mule/fixtures/bin doc/onebeer.txt docs/mule-workflow.html`
> and
> `rtk git diff --stat 5d80f88 -- lua/onebeer/mule/jobs lua/onebeer/mule/commands.lua lua/onebeer/mule/smoke.lua lua/onebeer/mule/fixtures/bin doc/onebeer.txt docs/mule-workflow.html`.
> This plan was written against an uncommitted Mule workflow draft and depends
> on Plan 013's command-boundary behavior. Stop if the baseline is untracked, the
> dependency is not DONE, or the current excerpts have changed.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: `plans/009-add-aggregate-mule-smoke-gate.md`, `plans/013-harden-mule-command-boundaries.md`
- **Category**: perf / dx
- **Planned at**: commit `5d80f88`, 2026-07-14, against the current uncommitted Mule workflow draft

## Why this matters

Every editor-facing Maven, MUnit, DataWeave, and Anypoint command waits
synchronously for its child process. A real Mule build or test can take minutes,
during which Neovim cannot process input or redraw. The underlying
`vim.system` API already supports callbacks; commands should return control to
the editor immediately while preserving the existing parsing, quickfix,
notification, and output-window contracts.

The current blocking wait also serializes commands accidentally. Removing it
allows users to start overlapping jobs, including two Maven processes targeting
the same project. This plan makes that trade-off explicit but does not add a
queue, lock, or concurrency policy.

## Current state

- `lua/onebeer/mule/jobs/process.lua:14-30` starts a process and immediately
  waits:

```lua
local ok, system_obj = pcall(vim.system, cmd, {
  cwd = opts and opts.cwd or nil,
  stdin = opts and opts.stdin or nil,
  text = true,
})
...
return system_obj:wait()
```

- Maven, MUnit, DataWeave, and Anypoint jobs all call `process.run`.
- `lua/onebeer/mule/commands.lua` invokes those jobs directly from user-command
  callbacks, so the wait happens on the editor thread.
- A 250 ms `/bin/sleep` probe through `process.run` took 258 ms before
  returning, confirming the synchronous boundary.
- Neotest is not affected; its adapter returns a command spec and Neotest owns
  the process lifecycle.
- Plan 013 defines the output and error behavior this refactor must preserve.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Process/command smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('commands')" +qa` | exit 0 |
| Maven smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('maven-build')" +qa` | exit 0 |
| MUnit smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('munit-runner')" +qa` | exit 0 |
| DataWeave smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('dataweave-cli')" +qa` | exit 0 |
| Anypoint smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('anypoint-cli')" +qa` | exit 0 |
| Aggregate Mule smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('all')" +qa` | exit 0 |
| Lua lint | `selene .` | exit 0 |
| Format check | `stylua --check .` | exit 0 |
| Help tags | `nvim --headless "+helptags doc" +qa` | exit 0 if help changes |

## Suggested executor toolkit

- Read the installed Neovim `vim.system()` help for callback and
  `vim.SystemObj` behavior.
- Use `vim.schedule_wrap` or an equivalent stable scheduling boundary before
  callbacks touch quickfix, buffers, windows, or notifications.
- Preserve argument vectors; never convert commands back into shell strings.

## Scope

**In scope**:

- `lua/onebeer/mule/jobs/process.lua`
- `lua/onebeer/mule/jobs/maven.lua`
- `lua/onebeer/mule/jobs/munit.lua`
- `lua/onebeer/mule/jobs/dataweave.lua`
- `lua/onebeer/mule/jobs/anypoint.lua`
- `lua/onebeer/mule/commands.lua`
- `lua/onebeer/mule/smoke.lua`
- `lua/onebeer/mule/fixtures/bin/**`
- `doc/onebeer.txt`
- `doc/tags` if help changes
- `docs/mule-workflow.html`
- `plans/README.md`

**Out of scope**:

- Neotest process execution.
- Adding cancellation, progress UI, queues, or concurrency limits.
- Running multiple Maven jobs safely in the same project.
- Replacing `vim.system`.
- Changing CLI arguments, cwd, parsing, or credential ownership.
- Removing synchronous job APIs that remain useful for deterministic direct
  smoke tests.

## Git workflow

- Branch: `advisor/014-async-mule-cli-jobs`
- Commit message: `perf: run mule cli jobs asynchronously`
- Do not push or open a PR unless explicitly instructed.
- Execute only after Plans 009 and 013 are DONE.

## Steps

### Step 1: Add a scheduled asynchronous process primitive

In `lua/onebeer/mule/jobs/process.lua`, add:

```lua
process.start(executable_key, args, opts, on_exit)
```

The helper must:

- Build the command through `config.command`.
- Start `vim.system` with the existing `cwd`, `stdin`, and `text` options.
- Return `vim.SystemObj|nil, string|nil` immediately.
- Invoke `on_exit(result, nil)` once when the process exits.
- Invoke or return an explicit start error when the process cannot be created.
- Schedule the completion callback before it can call Neovim stateful APIs.

Keep `process.run` for current synchronous direct-job tests, but implement shared
command construction and option normalization once.

**Verify**:
`stylua --check lua/onebeer/mule/jobs/process.lua`
-> exit 0.

### Step 2: Separate pure result handling from process lifecycle

For each job module, extract a private result-finalization helper that preserves
current behavior:

- Maven and MUnit: success result or quickfix population on non-zero exit.
- DataWeave: executable guard, quickfix parsing, and path context.
- Anypoint: missing/start/auth/command classification and decoded output.

Add explicit async entry points:

- `maven.build_async(opts, callback)`
- `munit.run_async(opts, callback)`
- `dataweave.validate_file_async(path, callback)`
- `dataweave.run_file_async(path, callback)`
- `anypoint.run_async(args, opts, callback)`

Callback shape must be consistent across modules:

```lua
callback(ok, result_or_error)
```

Do not duplicate parser or classification logic between sync and async paths.

**Verify**:
`stylua --check lua/onebeer/mule/jobs`
-> exit 0.

### Step 3: Move every external user command to async APIs

Update `lua/onebeer/mule/commands.lua`:

- `MuleBuild`, `MuleTest`, `MuleTestNearest`, `MuleDwValidate`, `MuleDwRun`,
  and `MuleStatus` must call the new async entry points.
- Return from the user-command callback immediately after a successful start.
- Surface start failures immediately.
- Preserve Plan 013 result rendering and catalog behavior.
- Run completion notifications, quickfix updates, and output windows only from
  the scheduled completion callback.
- Add concise start notifications only where users otherwise cannot tell the
  long-running job was accepted. Do not emit a success notification before
  completion.
- `MuleDwRepl` and `MuleGenerateCatalog` remain on their existing
  non-blocking/local paths.

Do not retain a hidden synchronous fallback in command callbacks.

**Verify**:
`rg -n "require\\(\"onebeer\\.mule\\.jobs\\.(maven|munit|dataweave|anypoint)\"\\)\\.(build|run|validate_file|run_file)\\(" lua/onebeer/mule/commands.lua`
-> no synchronous job call sites.

### Step 4: Add delayed fixtures that prove the editor callback returns

Add delayed fixture modes/scripts for at least Maven and Anypoint:

- Sleep for roughly 250 ms.
- Then emit the existing success payload.
- Remain POSIX-sh compatible with current fixture scripts.

Update command smoke helpers for async completion:

- Capture notifications over time without restoring `vim.notify` before the
  callback runs.
- Wait with bounded `vim.wait`, never an unbounded loop.
- Keep output-window collection active until the callback opens the window.
- Restore globals, buffers, windows, and scratch paths in all paths.

Add assertions that:

- Invoking the command returns in less than 100 ms while the fixture is still
  sleeping.
- The completion notification/output appears within a 2 second bound.
- Failure paths still populate quickfix or warnings after completion.

Use generous thresholds only for CI variance; the delay must be materially
longer than the immediate-return threshold.

**Verify**:
`nvim --headless "+lua require('onebeer.mule.smoke').run('commands')" +qa`
-> exit 0.

### Step 5: Re-run direct job and aggregate coverage

Keep synchronous direct job smoke stages passing so parsing and classification
remain independently testable. Then run the aggregate gate.

**Verify**:

1. `nvim --headless "+lua require('onebeer.mule.smoke').run('maven-build')" +qa`
   -> exit 0.
2. `nvim --headless "+lua require('onebeer.mule.smoke').run('munit-runner')" +qa`
   -> exit 0.
3. `nvim --headless "+lua require('onebeer.mule.smoke').run('dataweave-cli')" +qa`
   -> exit 0.
4. `nvim --headless "+lua require('onebeer.mule.smoke').run('anypoint-cli')" +qa`
   -> exit 0.
5. `nvim --headless "+lua require('onebeer.mule.smoke').run('all')" +qa`
   -> exit 0.

### Step 6: Document background execution

Update `doc/onebeer.txt` and `docs/mule-workflow.html` to say external Mule CLI
commands run in the background and report completion asynchronously. Do not
promise cancellation or progress reporting. State that starting another command
while one is active is currently allowed and unmanaged, so same-project jobs can
contend for Maven output such as `target/`. Regenerate help tags if needed.

**Verify**:
`rg -n "background|asynchronous|completion" doc/onebeer.txt docs/mule-workflow.html`
-> wording is accurate and does not claim out-of-scope controls.

## Test plan

- Delayed Maven command returns to Neovim before process completion.
- Delayed Anypoint command returns before completion and later opens output.
- Async success and failure preserve current notifications and quickfix.
- Direct synchronous job tests continue to validate parsers/classifiers.
- Missing executable and start-error paths invoke the callback exactly once.
- Aggregate smoke proves no shared callback state leaks between stages.

## Done criteria

- [ ] External `:Mule*` command callbacks do not call a path containing `SystemObj:wait()`.
- [ ] Commands return before delayed fixture processes finish.
- [ ] Completion behavior remains result-driven, not optimistic.
- [ ] Quickfix, notifications, and output windows are updated on the scheduled main-loop boundary.
- [ ] Direct Maven, MUnit, DataWeave, and Anypoint smoke stages still pass.
- [ ] `commands` and `all` smoke stages pass.
- [ ] `stylua --check .` and `selene .` exit 0.
- [ ] Docs describe background execution without promising cancellation.
- [ ] Docs disclose that overlapping same-project jobs are possible and
      currently unmanaged.
- [ ] No generated fixture or lockfile changes remain.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

Stop and report if:

- The Mule baseline is not committed before isolated execution.
- Plan 013 is not DONE or its result/error contracts have drifted.
- Stable `vim.system` callbacks cannot update Neovim state through a scheduled
  public API boundary.
- Async conversion requires changing command arguments, output meaning, or
  credential handling.
- Reliable smoke coverage would require arbitrary sleeps without bounded
  completion predicates.
- A job callback can fire more than once or after smoke cleanup has restored
  shared state.
- Any verification fails twice after a reasonable fix attempt.

## Maintenance notes

Keep process lifecycle and result interpretation separate. Future cancellation
or progress work should build on returned `vim.SystemObj` handles rather than
reintroducing waits or shell strings. Reviewers should scrutinize callback
cleanup and exactly-once completion behavior. A future queue or per-project
active-job guard can use the returned handles without changing result parsing.
