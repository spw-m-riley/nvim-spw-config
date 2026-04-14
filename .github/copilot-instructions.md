# Copilot instructions for this Neovim config

## Build, test, and lint commands

### Lint / formatting (repo-level)
- `selene .`
  Uses `selene.toml` (`std = "lua51+vim+onebeer"` and excludes `lua/onebeer/plugins/**`).
- `stylua --check .`
  Uses `.stylua.toml` (2 spaces, 120 columns, sorted requires).
- `stylua .`
  Apply formatting with the same config.

### Plugin/bootstrap and health checks
- `nvim --headless "+lua print(vim.inspect(vim.pack.get(nil, { info = false })))" +qa`
  Prints the current `vim.pack` plugin state / lockfile view.
- `nvim --headless "+checkhealth onebeer" +qa`
  Runs health checks implemented in `lua/onebeer/health.lua`.
- `nvim --headless "+checkhealth vim.lsp" +qa`
  Validates Neovim LSP client state.
- `nvim --headless "+helptags doc" +qa`
  Rebuild local help tags after updating `doc/onebeer.txt`.
- `gh auth status`
  Verify GitHub CLI auth before using Octo or other GitHub-backed features.

### Test commands
This repo does not define its own Lua unit test suite. Testing is configured through `neotest` for project code opened in Neovim:
- Single nearest test: `:lua require("neotest").run.run()` (keymap: `<leader>tt`)
- Single file tests: `:lua require("neotest").run.run(vim.fn.expand("%"))` (keymap: `<leader>tf`)
- Adapter details from `lua/onebeer/plugins/neotest.lua`:
  - Go adapter runs with `-count=1 -timeout=60s`
  - Jest adapter uses `npm test --`

## High-level architecture

- `init.lua` is the entrypoint. It enables the Lua loader, loads base settings (`onebeer.settings`), diagnostics/LSP defaults, computed runtime config (`onebeer.config`), plugins (`onebeer.pack`), a startup-time `snacks` fallback, autocmds, and tool commands.
- `lua/onebeer/pack.lua` bootstraps `vim.pack` and imports plugin specs from:
  - `lua/onebeer/plugins/**`
  - `lua/onebeer/plugins/lsp/**`
- `lua/onebeer/pack_modules.lua` owns plugin-module discovery and temporary exclusions such as `slides.nvim`.
- `lua/onebeer/plugin_spec.lua` defines the shared `onebeer.PluginSpec` annotations used by plugin files.
- LSP is split into layers:
  - Global behavior/handlers/capabilities in `lua/onebeer/settings/lsp/init.lua`
  - Server-specific configs in top-level `lsp/*.lua`
  - Server install policy in `lua/onebeer/plugins/lsp/mason.lua`
- Runtime workflow behavior is centralized in `lua/onebeer/autocmds/init.lua` (LSP attach maps, diagnostics UX, whitespace trimming, write-latency notifications, workflow linting for `.github/workflows/*`).
- Shared UI helpers live in `lua/onebeer/ui.lua`, with the native statusline renderer under `lua/onebeer/ui/statusline.lua`.

## Key conventions for changes

- Plugin definitions are one-file-per-plugin and return a `onebeer.PluginSpec` table.
- Reuse wrappers instead of calling raw APIs directly when touching existing patterns:
  - `onebeer.utils.safe_require`, `onebeer.utils.map`
  - `onebeer.autocmds.helpers.create_group/create_autocmd/create_command`
- Keep formatter ownership in `conform.nvim`; do not re-enable LSP formatting where it is intentionally disabled (example: `lsp/lua_ls.lua`).
- Keep config ownership aligned with the existing layers: `lsp/*.lua` owns server config, `lua/onebeer/plugins/lsp/mason.lua` owns install policy, `lua/onebeer/plugins/lint.lua` owns lint orchestration, and `lua/onebeer/autocmds/init.lua` owns cross-cutting UX/autocmd behavior.
- Use filetype constants from `lua/onebeer/settings/filetypes.lua` when mapping behavior by filetype.
- Treat `opts` as the payload for a plugin's `.setup(...)`; use `main` or `config` in the plugin spec to define how that setup path is reached.
- Keep plugin-specific module names in the plugin spec instead of adding loader-wide aliases.
- Respect existing toggle globals/buffer-vars instead of introducing new switches:
  - `vim.g.disable_autoformat` / `vim.b.disable_autoformat`
  - `vim.g.disable_lint` / `vim.b.disable_lint`
  - `vim.g.disable_trim_whitespace`
- Preserve the optional local override mechanism: `init.lua` conditionally loads `lua/onebeer/local.lua` when present.

### Session-learned guardrails

- Determine the target Neovim runtime with `nvim --version` before changing LSP/semantic-token/codelens APIs, keep that target fixed for the whole change, and do not bounce between stable/nightly API families mid-debugging. Verify against the runtime the user is actually on, not the one you assume.
- Before calling any plugin or Neovim API function, verify it against the installed version's actual source. Use `:help`/Neovim source for core APIs, and check `nvim-pack-lock.json` plus the installed plugin source before assuming third-party method names or config keys from upstream docs.
- For Neovim feature changes, validate the exact user-facing path instead of stopping at lint or syntax checks: open the target filetype/buffer in a focused repro, trigger the relevant autocmd/keymap/command, and confirm the runtime behavior actually happens (for example `:LspInfo` attach state in a real workflow file, or a Sidekick keymap execution). If only part of that path was tested, say so explicitly instead of claiming the fix is fully verified.
- When the user pastes error messages, logs, or debug output without an explicit instruction to fix/change something, treat it as informational context. Ask what action (if any) they'd like taken rather than immediately making changes.
- Before any fleet or SQL-tracked implementation round, resync `todos` and `todo_deps` to the currently approved plan and re-run the ready query. Do not trust stale pending rows or missing dependency edges after a plan rewrite.
- After sub-agents complete, diff their changes against the scoped task. Revert any modifications outside the requested scope before continuing. Do not leave out-of-scope edits for the user to discover later.
- Default to minimal, reversible edits: do not remove or disable plugins, or do major UI overhauls, without explicit user approval. For user-visible appearance changes, keep comparable polish and ship the replacement path/toggle in the same change instead of leaving a degraded interim state.
- Assume corporate network constraints can block non-official Copilot plugin endpoints; prefer Sidekick + Copilot CLI by default, and only change NES (`copilotInlineEdit`) or alternative Copilot stacks after connectivity is confirmed.
- When adding or changing an LSP, treat the runtime enable name, the `mason-lspconfig` `ensure_installed` identifier, and the executable command as separate values that all need verification. Do not assume names like `actionsls`, `gh_actions_ls`, and `gh-actions-language-server` are interchangeable.
- Avoid private `vim.lsp.*` internals and late startup mutations. If server startup args depend on `root_dir`, use function-form `cmd` instead of rewriting `config.cmd` in `before_init`, and implement `reuse_client` using stable persisted fields like `root_dir`.
- When diagnosing tool or LSP startup, do not assume `PATH` is the only source of truth. Check Mason-managed executables under `stdpath("data")/mason/bin`, other plugin-managed install paths, and keep `.github/lsp.json` portable and aligned with the repo's real tooling so Copilot CLI code intelligence matches the workspace.
- After `vim.pack` review or other plugin-manager validation, inspect tracked changes before finishing. Do not keep or commit `nvim-pack-lock.json` churn unless dependency updates are explicitly in scope.
- When building `statusline`, `winbar`, or `tabline` strings, use `table.concat` instead of `string.format` to avoid conflicts with Vim's `%`-based statusline evaluation syntax.
- For config changes, run validation instead of leaving checks unrun: `selene .`, `stylua --check .`, `nvim --headless "+lua print(vim.inspect(vim.pack.get(nil, { info = false })))" +qa`; for LSP/plugin changes also run `nvim --headless "+checkhealth onebeer" +qa`.
