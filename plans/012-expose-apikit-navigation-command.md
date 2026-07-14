# Plan 012: Expose APIKit navigation through an editor command

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the next
> step. If anything in the "STOP conditions" section occurs, stop and report;
> do not improvise. When done, update the status row for this plan in
> `plans/README.md` unless your dispatcher owns the index.
>
> **Drift check (run first)**:
> `rtk git status --short -- lua/onebeer/mule/api/apikit.lua lua/onebeer/mule/index.lua lua/onebeer/mule/commands.lua lua/onebeer/mule/smoke.lua lua/onebeer/mule/fixtures/projects/basic-mule doc/onebeer.txt docs/mule-workflow.html`
> and
> `rtk git diff --stat 5d80f88 -- lua/onebeer/mule/api/apikit.lua lua/onebeer/mule/index.lua lua/onebeer/mule/commands.lua lua/onebeer/mule/smoke.lua lua/onebeer/mule/fixtures/projects/basic-mule doc/onebeer.txt docs/mule-workflow.html`.
> This plan was written against an uncommitted Mule workflow draft. Stop if the
> baseline remains untracked or the current excerpts have changed.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/009-add-aggregate-mule-smoke-gate.md`
- **Category**: direction / dx
- **Planned at**: commit `5d80f88`, 2026-07-14, against the current uncommitted Mule workflow draft

## Why this matters

The plugin contains a tested resolver that maps generated APIKit flow names to
local RAML and OpenAPI routes, and both help surfaces advertise that workflow.
No command, keymap, autocmd, or navigation handler calls the resolver outside
the smoke suite. The feature is therefore implemented but unreachable from the
editor; exposing one narrow command turns the existing code into a real user
workflow without inventing a Studio-style UI.

## Current state

- `lua/onebeer/mule/api/apikit.lua:183-225` implements
  `route_for_flow(xml_path, flow_name)` and returns a spec path plus line.
- Repository search finds `route_for_flow` only in that module and
  `lua/onebeer/mule/smoke.lua:577-630`.
- `lua/onebeer/mule/commands.lua:244-272` registers eight `:Mule*` commands, but
  none navigate APIKit flows.
- `doc/onebeer.txt:627-635` and
  `docs/mule-workflow.html:342-350` describe APIKit navigation without naming
  an invocation.
- `lua/onebeer/mule/index.lua:49-68` discovers flow and APIKit config attributes
  from one physical line. The command must not claim support for a declaration
  shape that the fixture suite never exercises.
- Command registration uses
  `onebeer.autocmds.helpers.create_command`; match the existing command module.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| APIKit smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('apikit-navigation')" +qa` | exit 0 |
| Command smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('commands')" +qa` | exit 0 |
| Aggregate Mule smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('all')" +qa` | exit 0 |
| Lua lint | `selene .` | exit 0 |
| Format check | `stylua --check .` | exit 0 |
| Help tags | `nvim --headless "+helptags doc" +qa` | exit 0 |

## Scope

**In scope**:

- `lua/onebeer/mule/api/apikit.lua`
- `lua/onebeer/mule/index.lua`
- `lua/onebeer/mule/commands.lua`
- `lua/onebeer/mule/smoke.lua`
- `lua/onebeer/mule/fixtures/projects/basic-mule/src/main/mule/**`
- `lua/onebeer/mule/fixtures/projects/basic-mule/src/main/resources/api/**`
- `doc/onebeer.txt`
- `doc/tags`
- `docs/mule-workflow.html`
- `plans/README.md`

**Out of scope**:

- Remote Exchange downloads or credentials.
- A full RAML, OpenAPI, or XML parser dependency.
- Overriding core `gd`, `gf`, or LSP navigation globally.
- A fuzzy picker or project-wide API route browser.
- Navigating from arbitrary lines inside a flow body.

## Git workflow

- Branch: `advisor/012-expose-apikit-navigation`
- Commit message: `feat: expose mule apikit navigation`
- Do not push or open a PR unless explicitly instructed.
- Stop before worktree creation if the Mule baseline is uncommitted.

## Steps

### Step 1: Add a command-ready generated-flow lookup

In `lua/onebeer/mule/index.lua` and `api/apikit.lua`, add a small helper that
returns the generated APIKit flow declaration at a requested cursor line:

- Accept only Mule XML.
- Match a `<flow ... name="...">` opening tag whose declaration spans the
  requested line.
- Parse `name` independently of attribute order.
- Support an opening tag split across multiple physical lines by accumulating
  only through its first `>`.
- Return the declaration's start line and name.
- Return `nil` outside a generated APIKit flow declaration; do not silently use
  the previous flow in the file.

Use the same bounded start-tag helper for `apikit:config` so `name` and `api`
work in either attribute order and across multiple declaration lines. Do not
turn this into a general XML parser.

Add fixture declarations that prove multiline flow and config attributes.

**Verify**:
`nvim --headless "+lua require('onebeer.mule.smoke').run('apikit-navigation')" +qa`
-> exit 0 with new multiline and attribute-order assertions.

### Step 2: Register `:MuleApiNavigate`

Add a no-argument `MuleApiNavigate` callback in
`lua/onebeer/mule/commands.lua`:

1. Read the current buffer path and cursor line.
2. Resolve the generated flow declaration through the APIKit helper.
3. If the cursor is not on a generated APIKit flow declaration, warn:
   `Place the cursor on an APIKit generated <flow> declaration`.
4. Call `route_for_flow(path, flow_name)`.
5. On success, edit the local spec path in the current window and place the
   cursor on the returned line.
6. On failure, surface the exact resolver error at WARN level without a stack
   trace.

Use `vim.fn.fnameescape` when editing the target. Keep the command synchronous;
it performs only local file reads.

Register it with `create_command`, omit `nargs` so Neovim keeps the default
zero-argument contract, and add a precise description.

**Verify**:
`stylua --check lua/onebeer/mule/commands.lua`
-> exit 0.

### Step 3: Exercise the actual command path

Extend the `commands` smoke stage:

- Open the Mule API fixture on a generated RAML flow declaration.
- Run `:MuleApiNavigate`.
- Assert the current buffer becomes `basic.raml` and the cursor reaches the
  expected method line.
- Repeat for the OpenAPI fixture.
- Assert a normal Mule flow warns and stays in the original buffer.
- Assert a `resource::` flow reports the existing offline-only error and does
  not change buffers.
- Restore the original buffer after every case.

Add `MuleApiNavigate` to `mule_command_names` so smoke setup remains isolated.

**Verify**:
`nvim --headless "+lua require('onebeer.mule.smoke').run('commands')" +qa`
-> exit 0.

### Step 4: Document the invocation and boundaries

Update `doc/onebeer.txt` and `docs/mule-workflow.html`:

- Add `MuleApiNavigate` to the command reference.
- Show the exact workflow: place the cursor on a generated APIKit `<flow>`
  declaration and run the command.
- State that local RAML and OpenAPI are supported.
- Keep `resource::` Exchange references explicitly offline-only.
- Do not imply navigation from arbitrary processor lines or automatic keymap
  interception.

Regenerate help tags.

**Verify**:

1. `rg -n "MuleApiNavigate|APIKit generated" doc/onebeer.txt docs/mule-workflow.html`
   -> both docs name the command and cursor requirement.
2. `nvim --headless "+helptags doc" +qa` -> exit 0.

## Test plan

- RAML top-level flow command navigation.
- RAML nested route command navigation.
- OpenAPI route command navigation.
- Multiline/attribute-reordered flow and `apikit:config` declarations.
- Non-generated Mule flow warning.
- Offline Exchange error with no buffer change.
- Non-Mule XML refusal remains covered by the APIKit stage.

## Done criteria

- [ ] `:MuleApiNavigate` is registered and documented.
- [ ] The command navigates RAML and OpenAPI fixtures to the expected line.
- [ ] Multiline and reordered APIKit attributes are covered.
- [ ] Unsupported cursor locations and Exchange specs warn without changing buffers.
- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('apikit-navigation')" +qa` exits 0.
- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('commands')" +qa` exits 0.
- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('all')" +qa` exits 0.
- [ ] `stylua --check .`, `selene .`, and help-tag generation exit 0.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

Stop and report if:

- The Mule baseline is not committed before isolated execution.
- Correct cursor lookup requires a general XML parser or Treesitter parser not
  already guaranteed by the config.
- Neovim command parsing would require users to pass backslash-heavy flow names
  manually; keep the command cursor-driven instead.
- Opening the target safely requires a global navigation override.
- Supporting multiline tags widens into parsing arbitrary XML content rather
  than bounded opening tags.
- Any verification fails twice after a reasonable fix attempt.

## Maintenance notes

Keep route resolution pure and command navigation thin. If a picker or broader
navigation UI is added later, it should reuse the same resolver and fixture
contract rather than reparsing flow names independently.
