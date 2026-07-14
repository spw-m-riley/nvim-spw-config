# Plan 010: Wire generated Mule catalogs into live LemMinX clients

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the next
> step. If anything in the "STOP conditions" section occurs, stop and report;
> do not improvise. When done, update the status row for this plan in
> `plans/README.md` unless your dispatcher owns the index.
>
> **Drift check (run first)**:
> `rtk git status --short -- lsp/lemminx.lua lua/onebeer/mule/integrations/lemminx.lua lua/onebeer/mule/commands.lua lua/onebeer/mule/health.lua lua/onebeer/mule/smoke.lua doc/onebeer.txt docs/mule-workflow.html`
> and
> `rtk git diff --stat 5d80f88 -- lsp/lemminx.lua lua/onebeer/mule/integrations/lemminx.lua lua/onebeer/mule/commands.lua lua/onebeer/mule/health.lua lua/onebeer/mule/smoke.lua doc/onebeer.txt docs/mule-workflow.html`.
> This plan was written against an uncommitted Mule workflow draft and depends
> on Plan 013's catalog failure contract. Stop if the baseline remains untracked,
> the dependency is not DONE, or the current contracts no longer match.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/009-add-aggregate-mule-smoke-gate.md`, `plans/013-harden-mule-command-boundaries.md`
- **Category**: bug / dx
- **Planned at**: commit `5d80f88`, 2026-07-14, against the current uncommitted Mule workflow draft

## Why this matters

`:MuleGenerateCatalog` currently creates a valid local catalog but the enabled
LemMinX client never receives it. The effective server config has empty
settings and uses the repository `.git` root, while the Mule-specific settings
helper is only exercised by smoke tests. Users are told local XML validation is
configured when the live editor path still behaves like stock LemMinX.

## Current state

- `lua/onebeer/mule/integrations/lemminx.lua:9-31` can build catalog settings
  for a Mule buffer:

```lua
function M.settings(bufnr)
  ...
  return {
    settings = {
      xml = {
        catalogs = { catalog_path },
      },
    },
  }
end
```

- The helper is referenced only by
  `lua/onebeer/mule/smoke.lua:632-730`.
- `lua/onebeer/plugins/lsp/mason.lua:63-67,184-187` installs and enables
  `lemminx`, but the repository has no `lsp/lemminx.lua`.
- The installed `nvim-lspconfig` default only supplies `cmd`, `filetypes`, and
  `root_markers = { ".git" }`.
- A live headless probe on the Mule fixture on 2026-07-14 produced:

```lua
{
  root_dir = "<repo-root>",
  settings = {},
}
```

- `doc/onebeer.txt:641-643` and
  `docs/mule-workflow.html:333-340` say LemMinX uses the local catalog once it
  exists.
- Neovim 0.13 supports stable function-form `root_dir(bufnr, on_dir)`,
  `before_init(_, config)`, mutable client settings, and
  `workspace/didChangeConfiguration`. Follow the existing dynamic-settings
  pattern in `lsp/pyright.lua:6-26`.
- LemMinX documents the setting as `xml.catalogs`.
- Plan 013 owns `catalog.generate` failure propagation and the nil-path
  notification branch in `generate_catalog()`. This plan must add refresh
  behavior without weakening or replacing that contract.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Catalog smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('lemminx-catalog')" +qa` | exit 0 |
| Aggregate Mule smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('all')" +qa` | exit 0 |
| OneBeer health | `nvim --headless "+checkhealth onebeer" +qa` | exit 0, no Lua errors |
| LSP health | `nvim --headless "+checkhealth vim.lsp" +qa` | exit 0 |
| Lua lint | `selene .` | exit 0 |
| Format check | `stylua --check .` | exit 0 |
| Help tags | `nvim --headless "+helptags doc" +qa` | exit 0 |

## Suggested executor toolkit

- Use Neovim's shipped `lsp.txt` for the exact `root_dir`, `before_init`, and
  client settings contracts.
- Use the installed `nvim-lspconfig/lsp/lemminx.lua` only as the upstream
  default to merge with; do not copy stale setup patterns.
- Use the LemMinX `xml.catalogs` preference documentation:
  `https://github.com/redhat-developer/vscode-xml/blob/main/docs/Preferences.md`.

## Scope

**In scope**:

- `lsp/lemminx.lua` (create)
- `lua/onebeer/mule/integrations/lemminx.lua`
- `lua/onebeer/mule/commands.lua`
- `lua/onebeer/mule/health.lua`
- `lua/onebeer/mule/smoke.lua`
- `doc/onebeer.txt`
- `doc/tags`
- `docs/mule-workflow.html`
- `plans/README.md`

**Out of scope**:

- Downloading schemas or Maven artifacts.
- Changing catalog discovery rules.
- Applying Mule catalogs to generic XML files.
- Using private `vim.lsp.*` internals.
- Restarting every LemMinX client globally after catalog generation.

## Git workflow

- Branch: `advisor/010-wire-mule-lemminx-catalogs`
- Commit message: `fix: wire mule catalogs into lemminx`
- Do not push or open a PR unless explicitly instructed.
- Stop before worktree creation if the Mule baseline is not committed or Plan
  013 is not DONE.

## Steps

### Step 1: Turn the integration helper into the single settings seam

Before changing code, confirm the installed LemMinX preference source still
names `xml.catalogs`. When the LemMinX executable is available, run a minimal
project-local probe that sends `workspace/didChangeConfiguration` and confirm
the server accepts the notification; stop before building the refresh path if
the server demonstrably rejects or ignores the setting. If the executable is
unavailable, record that the deterministic fake-client contract remains
mandatory and the optional live probe will be skipped.

Refactor `lua/onebeer/mule/integrations/lemminx.lua` to expose small stable
helpers:

- `settings_for_path(path)` returns the server settings payload
  `{ xml = { catalogs = { absolute_catalog_path } } }` only when:
  - `path` belongs to a Mule XML buffer,
  - a Mule project is detected, and
  - the generated catalog exists.
- `settings_for_root(root)` returns the same payload from an already selected
  Mule project root, or `{}` when no generated catalog exists.
- `root_dir(bufnr, on_dir)` chooses the Mule project root for Mule XML buffers.
  For non-Mule XML, preserve normal LemMinX behavior by falling back to the
  nearest `.git` root or the file's parent directory.
- `apply(client, path)` merges the Mule settings into the public client settings
  field and sends `workspace/didChangeConfiguration` using the same stable
  pattern as `lsp/pyright.lua`.
- `refresh(path)` applies settings only to active `lemminx` clients whose
  persisted `root_dir` matches the detected Mule project.

Do not return the extra `{ settings = ... }` wrapper from
`settings_for_path`; that wrapper belongs in the LSP config, not the reusable
settings value.

**Verify**:
`stylua --check lua/onebeer/mule/integrations/lemminx.lua`
-> exit 0.

### Step 2: Add the repo-owned LemMinX configuration

Create `lsp/lemminx.lua` as a `vim.lsp.Config` override that merges with the
installed upstream config:

- Set `root_dir` to the integration helper.
- In `before_init(_, config)`, merge
  `settings_for_root(config.root_dir)` into `config.settings`.
- Do not repeat upstream `cmd` or `filetypes` unless the installed source proves
  an override is necessary.
- Keep generic XML activation intact.

The result must create separate LemMinX clients for distinct Mule project roots
instead of reusing one repository-wide client.

**Verify**:

```sh
nvim --headless \
  "+lua local c=vim.lsp.config.lemminx; assert(type(c.root_dir)=='function'); print(vim.inspect(c))" \
  +qa
```

Expected: exit 0 and a function-form `root_dir`.

If `vim.lsp.config.lemminx` is nil, first confirm that the installed
`nvim-lspconfig` `lsp/` directory is on the headless runtimepath. Treat a plugin
loading failure as an environment/setup problem, not evidence that the override
shape is wrong.

### Step 3: Refresh the live client after catalog generation

Start from Plan 013's hardened `generate_catalog()` shape: retain its
`catalog.generate(...)` error notification and early return exactly. After the
returned catalog path is non-nil:

1. Call the LemMinX integration refresh helper with the current Mule path.
2. Keep the existing success notification.
3. If no LemMinX client is active, still report catalog generation success; the
   next client start will pick it up through `before_init`.
4. Do not hide refresh errors. Return or notify an actionable error consistent
   with the command's existing failure path.
5. Do not report the catalog as unwritten when only the live-client refresh
   fails; distinguish "catalog written, refresh failed" from a catalog write
   failure.

**Verify**:
`stylua --check lua/onebeer/mule/commands.lua`
-> exit 0.

### Step 4: Strengthen fixture-backed LSP configuration coverage

Extend the `lemminx-catalog` smoke stage to prove:

- The root helper returns the fixture Mule root for a Mule XML buffer.
- The settings helper returns the generated absolute catalog path.
- A fake public client receives merged `xml.catalogs` settings and exactly one
  `workspace/didChangeConfiguration` notification.
- Generic resource XML still receives no Mule catalog settings.
- The effective `vim.lsp.config.lemminx` includes the repo-owned root function.

If `lemminx` is executable in the validation environment, add an optional live
probe that opens the fixture, waits for the client, and asserts its root and
catalog setting. The deterministic fake-client assertions remain mandatory so
the smoke stage does not depend on host tooling.

**Verify**:
`nvim --headless "+lua require('onebeer.mule.smoke').run('lemminx-catalog')" +qa`
-> exit 0.

### Step 5: Make health and docs describe the real runtime path

Update Mule health so, when the current buffer is Mule XML, it reports whether:

- the project catalog exists, and
- an active LemMinX client for that project currently has the catalog setting.

Keep missing catalogs informational until the user asks to generate one.

Update `doc/onebeer.txt` and `docs/mule-workflow.html` to say that catalog
generation updates an active project-local LemMinX client and is picked up on
the next start when no client is active. Regenerate help tags.

**Verify**:

1. `nvim --headless "+checkhealth onebeer" +qa` -> exit 0.
2. `nvim --headless "+helptags doc" +qa` -> exit 0.

## Test plan

- Unit-style smoke assertions cover settings construction, project-root
  selection, client mutation, and configuration notification.
- Existing catalog discovery and empty-catalog behavior remain covered.
- Generic XML remains unaffected.
- An optional real LemMinX probe validates the exact user-facing path when the
  binary is available.

## Done criteria

- [ ] `lsp/lemminx.lua` exists and uses stable function-form `root_dir`.
- [ ] Mule XML starts LemMinX with the Mule project as `root_dir`.
- [ ] Existing generated catalogs populate `settings.xml.catalogs` before initialization.
- [ ] `:MuleGenerateCatalog` refreshes the matching active LemMinX client.
- [ ] Plan 013's catalog write/error notifications remain intact.
- [ ] Generic XML does not inherit Mule catalog settings.
- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('lemminx-catalog')" +qa` exits 0.
- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('all')" +qa` exits 0.
- [ ] `stylua --check .` and `selene .` exit 0.
- [ ] Help tags regenerate successfully.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

Stop and report if:

- The Mule baseline is not committed before isolated execution.
- Plan 013 is not DONE or its catalog result/error contract has drifted.
- Correct project-local behavior requires private LSP fields or late mutation of
  startup internals.
- LemMinX does not honor `workspace/didChangeConfiguration` for
  `xml.catalogs`; document the observed server behavior before changing the
  design.
- Preserving generic XML support requires a separate incompatible LemMinX
  configuration name.
- A live client would need a global restart instead of a project-scoped refresh.
- Any verification fails twice after a reasonable fix attempt.

## Maintenance notes

Keep all Mule-specific LemMinX behavior behind the integration module. Future
catalog changes should not write directly into LSP client state from command
callbacks. Reviewers should verify both startup-time settings and the
post-generation refresh path.
