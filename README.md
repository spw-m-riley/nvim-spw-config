# OneBeer Neovim

A personal Neovim configuration built around the idea that your editor should get out of the way and let you write great code. Fast, opinionated, and thoughtfully assembled — like a well-made beer.

---

## What is this?

This is a full-featured Neovim setup built on [lazy.nvim](https://github.com/folke/lazy.nvim). It covers everything from LSP to AI assistance, debugging to git workflows, all with lazy-loading so startup stays snappy.

The namespace is `onebeer` and every module lives under `lua/onebeer/`. The entry point is `init.lua`, which boots the config in a deliberate sequence: utilities → settings → diagnostics → LSP → plugins → health → autocommands → custom commands → optional local overrides.

If you want a friendly in-editor reference, use `:h onebeer`. For the quick floating
cheatsheet, tap `<leader>uh` or run `:OneBeerHelp`.

---

## How it's structured

```
.config/nvim/
├── init.lua                   # Entry point
├── lsp/                       # Per-server LSP configs
│   ├── actionsls.lua
│   ├── gleam.lua
│   ├── gopls.lua
│   ├── lua_ls.lua
│   ├── pyright.lua
│   ├── ruff.lua
│   ├── ruby_lsp.lua
│   ├── rust_analyzer.lua
│   ├── terraformls.lua
│   ├── ts_ls.lua
│   └── zls.lua
└── lua/onebeer/
    ├── config.lua             # Feature flags (Copilot on/off per directory)
    ├── lazy.lua               # Plugin manager bootstrap
    ├── health.lua             # Health checks + dependency auto-installer
    ├── state.lua              # Shared runtime state
    ├── ui.lua                 # Float styling helpers
    ├── utils.lua              # Safe require, keymap helpers
    ├── keymaps/               # Core keybindings
    ├── autocmds/              # Autocommands grouped by concern
    ├── settings/              # Editor options, theme, diagnostics, filetypes
    ├── tools/                 # Custom commands (JSON → Go/TypeScript converters)
    ├── snippets/              # LuaSnip snippets for Lua, Go, Astro
    └── plugins/               # One file per plugin, all LazySpecs
        └── lsp/               # LSP-specific plugin configs
```

### Key conventions

- Every plugin lives in its own file under `plugins/` and returns a `LazySpec` table.
- All `require` calls go through `utils.safe_require` (a `pcall` wrapper) so a broken plugin never crashes the whole config.
- Shared helpers (`onebeer.utils.map`, `onebeer.autocmds.helpers`) keep boilerplate out of plugin files.
- Format-on-save and lint-on-save each have global and buffer-local toggles (`vim.g.disable_autoformat`, `vim.b.disable_lint`, etc.) — you can flip them without reloading anything.
- A `lua/onebeer/local.lua` file, if it exists, is loaded last. Put machine-specific overrides there and keep them out of git.

---

## Language support

LSP enablement is centralized in `lua/onebeer/plugins/lsp/mason.lua`, while each repo-root `lsp/*.lua` file still owns its server-specific config. Mason installs the shared first-class server set, and runtime-owned servers stay opt-in when their executable is already on `PATH`. `.github/lsp.json` mirrors the extension-safe subset for Copilot CLI code intelligence.

| Language | Surface | Ownership notes |
|---|---|---|
| Go | `gopls` + Treesitter + `goimports` | Inlay hints, shadow/unused analysis, and codelenses stay with `gopls` |
| TypeScript / JavaScript | `ts_ls` + Treesitter + Prettier + ESLint | `ts_ls` owns code intelligence; `nvim-lint` keeps the existing JS/TS fast/save split |
| Lua | `lua_ls` + Treesitter + `stylua` | Neovim-aware workspace, strict scanning limits, formatting off in LSP |
| Python | `pyright` + `ruff` + Treesitter + `ruff format` | Pyright owns type analysis, Ruff owns imports/formatting, and diagnostics stay with the LSP pair |
| Rust | `rust_analyzer` + Treesitter + `rustfmt` | `rust_analyzer` handles diagnostics/code actions; Conform keeps `rustfmt` ownership |
| Ruby | `ruby_lsp` + Treesitter + `rubocop` | Ruby stays runtime-owned; shared policy will not prefer a Mason-managed gem over your active Ruby environment |
| Zig | `zls` + Treesitter + `zig fmt` | `zls` owns diagnostics/code actions; Conform owns formatting |
| Gleam | `gleam` + Treesitter + `gleam format` | Explicit partial support: runtime-managed LSP/formatter, no extra `nvim-lint` layer |
| SQL | Treesitter + `sqlfluff` | Explicit partial support in wave 1: parser + formatter only, no SQL LSP |
| GitHub Actions | `gh_actions_ls` | Path-aware YAML support in Neovim; not mirrored in `.github/lsp.json` because that config is extension-only |

Astro, HTML, JSON, Shell, and Terraform keep their existing curated server surface (`astro`, `html`, `jsonls`, `bashls`, `terraformls`) without changing ownership.

### Formatting & linting

Formatting is handled by [conform.nvim](https://github.com/stevearc/conform.nvim) — it owns format-on-save for every supported filetype. LSP formatting is intentionally disabled wherever conform has a better tool (e.g. `lua_ls` defers to `stylua`).

The main formatter paths are:

- `stylua` for Lua
- `ruff format` for Python
- `rubocop` for Ruby
- `rustfmt` for Rust
- `zig fmt` for Zig
- `sqlfluff` for SQL
- `shfmt` first, `beautysh` fallback for `sh` / `zsh`
- `prettierd` first, `prettier` fallback for JS / TS / web filetypes

Linting runs through [nvim-lint](https://github.com/mfussenegger/nvim-lint) with a split low-latency workflow:

- JS / TS / Astro use `oxlint` on `InsertLeave`, with optional `eslint_d` when it is installed
- JS / TS / Astro use `eslint` on `BufWritePost`
- Markdown / prose use `markdownlint`, `write-good`, and `woke` on save
- Shell / YAML / Terraform / Docker / gitcommit / GitHub Actions use `shellcheck`, `yamllint`, `tflint`, `hadolint`, `gitlint`, and `actionlint`
- Python / Rust / Ruby / Zig diagnostics stay LSP-owned, and Gleam / SQL intentionally skip `nvim-lint` in wave 1

---

## Plugins worth knowing about

### UI

- **[Catppuccin Mocha](https://github.com/catppuccin/nvim)** — the theme. Transparent background, custom highlight overrides, and colours extracted at runtime for the statusline.
- **[snacks.nvim](https://github.com/folke/snacks.nvim)** — dashboard, notifications, indent guides, statuscolumn, smooth scrolling, and scope visualisation in one package.
- **[lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)** — statusline with a custom "bubbles" theme, Vi mode colours, active LSP clients, git diff stats, and a branch indicator.
- **[tiny-inline-diagnostic.nvim](https://github.com/rachartier/tiny-inline-diagnostic.nvim)** — inline diagnostics that stay out of your way.
- **[precognition.nvim](https://github.com/tris203/precognition.nvim)** — shows motion targets (`w`, `b`, `e`, `$`, `G`, `gg`, `{`, `}`) as hints so you always know where you're going. > Great for building muscle memory.
- **[mini.clue](https://github.com/echasnovski/mini.clue)** — keymap hint popup on leader / `g` / `z` with 50+ custom descriptions.

### Navigation

- **[fzf-lua](https://github.com/ibhagwan/fzf-lua)** — fuzzy everything: files, buffers, LSP symbols, references, git log, frecency.
- **[flash.nvim](https://github.com/folke/flash.nvim)** — jump anywhere on screen in a keystroke or two.
- **[grapple.nvim](https://github.com/cbochs/grapple.nvim)** — tag files you care about, scoped per git repo. Instant switching between your hot files.
- **[mini.files](https://github.com/echasnovski/mini.files)** — file explorer in a floating window.

### Completion & snippets

- **[blink.cmp](https://github.com/Saghen/blink.cmp)** — completion engine wired up to LSP, Copilot ghost text, LuaSnip, and lazydev (Neovim API completions in lua files).
- **[LuaSnip](https://github.com/L3MON4D3/LuaSnip)** — snippets for Go, Lua, and Astro. Includes custom utilities that pull import paths, class names, and function signatures from the current buffer.

### Git

- **[gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim)** — hunk signs, inline blame, staging hunks without leaving the buffer.
- **[neogit](https://github.com/NeogitOrg/neogit)** + **[diffview.nvim](https://github.com/sindrets/diffview.nvim)** — a Magit-style git interface with a full diff viewer. Commit, rebase, and resolve conflicts without leaving Neovim.
- **[octo.nvim](https://github.com/pwntester/octo.nvim)** — the GitHub workflow layer. List and edit issues, PRs, discussions, and notifications from Neovim while leaving core Git work to Neogit, Diffview, and Gitsigns.

  Default entry points:

  - **`<leader>oi`** — GitHub issues
  - **`<leader>op`** — GitHub pull requests
  - **`<leader>od`** — GitHub discussions
  - **`<leader>on`** — GitHub notifications

### Testing & debugging

- **[neotest](https://github.com/nvim-neotest/neotest)** — run Go tests, Jest, and Vitest from inside the editor. Nearest test, file, or full suite.
- **[nvim-dap](https://github.com/mfussenegger/nvim-dap)** + **dap-ui** — debugger UI with Go and Node.js adapters.

### AI

- **[copilot.lua](https://github.com/zbirenbaum/copilot.lua)** — GitHub Copilot completions, integrated as a blink source for ghost text. Automatically disabled in directories listed in `config.lua`'s `nopilot_dirs`.
- **Sidekick** — Copilot CLI wrapper with a curated set of prompts accessible from a picker:

  | Prompt | What it does |
  |---|---|
  | `explain` | Explain purpose, logic, and design decisions |
  | `fix` | Fix diagnostics with minimal changes |
  | `refactor` | Improve clarity and simplicity |
  | `optimize` | Performance analysis with tradeoff notes |
  | `tests` | Generate tests — happy path, edge cases, errors |
  | `docs` | Add doc comments (JSDoc / LuaDoc / GoDoc style) |
  | `types` | Add type annotations |
  | `review` | Full file review for bugs, security, and perf |
  | `commit` | Generate a conventional commit message |

### Utilities

- **[trouble.nvim](https://github.com/folke/trouble.nvim)** — browse diagnostics, references, and quickfix lists in a dedicated panel.
- **[undotree](https://github.com/mbbill/undotree)** — visual undo history. Never lose a change.
- **[persistence.nvim](https://github.com/folke/persistence.nvim)** — automatically saves and restores sessions per working directory.
- **[multicursor.nvim](https://github.com/jake-stewart/multicursor.nvim)** — multiple cursors when you really need them.
- **[slides.nvim](https://github.com/sphamba/smear-cursor.nvim)** — build and present code slides without leaving Neovim. Handy for demos and walkthroughs.

---

## Custom commands and tools

| Command | What it does |
|---|---|
| `:FormatToggle` / `:FormatToggleBuffer` | Toggle format-on-save globally or for the current buffer |
| `:LintToggle` / `:LintToggleBuffer` | Toggle linting globally or for the current buffer |
| `:TrimWhitespaceToggle` | Toggle automatic trailing whitespace removal on save |
| `:InspectLog` | Open the LSP log file |
| `:LoaderResetCache` | Clear the Lua module loader cache |

There are also two JSON conversion tools:

- **`<leader>jg`** — converts a JSON selection to a Go struct (uses [`gojson`](https://github.com/ChimeraCoder/gojson))
- **`<leader>jt`** — converts a JSON selection to a TypeScript interface (uses [`quicktype`](https://github.com/quicktype/quicktype))

---

## Getting started

### Requirements

- Neovim >= 0.11.0
- `git`, `ripgrep` (`rg`), `fzf`, `gh` ([GitHub CLI](https://cli.github.com/))
- A [Nerd Font](https://www.nerdfonts.com/) — the config is set up with MonoLisa Nerd Font but any will work

### Recommended

- [mise](https://mise.jdx.dev/) — for managing `node` and `go` installs
- `brew` — for system-level tooling

### Installation

Clone this repo into your Neovim config directory:

```sh
git clone <your-repo-url> ~/.config/nvim
```

Then open Neovim. Lazy.nvim will bootstrap itself and install all plugins on first launch. Mason will install LSP servers, and the health check will guide you through any missing external tools.

### Health check

Run `:checkhealth onebeer` to see the status of every external dependency. It reports exact versions for the core toolchain, keeps the guided installer flow for the existing brew → mise → go → gojson chain when you run it interactively, and calls out language-surface tools such as `ruff`, `rustfmt`, `sqlfluff`, `ruby-lsp`, `rubocop`, `gleam`, `zig`, and `zls` without pretending missing runtime-managed tools are already healthy. If it's your first time setting up, start here.

Server, client, and parser state stay in their own providers: `:checkhealth vim.lsp`, `:checkhealth mason`, and `:checkhealth ts-install`.

Verified extra `:checkhealth` providers in this environment are `lazy`, `mason`, `nvim-treesitter`, `sidekick`, `snacks`, `ts-install`, and `fzf-lua-frecency`. `:checkhealth copilot` is intentionally not listed because it currently returns `No healthcheck found for "copilot" plugin`.

If you plan to use `octo.nvim`, also make sure `gh auth status` succeeds. Features that touch GitHub Projects v2 may additionally require refreshing your token with the `read:project` scope.

### Local overrides

Create `lua/onebeer/local.lua` for anything machine-specific — fonts, transparency settings, extra keymaps, whatever doesn't belong in version control. It's loaded last and not tracked by git.

---

## Development and linting

When working on the config itself, use this validation matrix:

| Tier | Command | What it validates |
|---|---|---|
| Core | `selene .` | Lua lint across the repo |
| Core | `stylua --check .` | formatting drift |
| Core | `nvim --headless "+Lazy! check" +qa` | plugin manager / lockfile state |
| Core | `nvim --headless "+checkhealth onebeer" +qa` | repo-owned dependency and language-tooling readiness |
| Core | `nvim --headless "+checkhealth vim.lsp" +qa` | Neovim LSP client state |
| Verified add-on | `nvim --headless "+checkhealth lazy" +qa` | `lazy.nvim` + luarocks environment |
| Verified add-on | `nvim --headless "+checkhealth mason" +qa` | Mason registry and external runtime availability |
| Verified add-on | `nvim --headless "+checkhealth nvim-treesitter" +qa` | parser runtime/tooling state |
| Verified add-on | `nvim --headless "+checkhealth sidekick" +qa` | Copilot LSP + optional AI CLI surface |
| Verified add-on | `nvim --headless "+checkhealth snacks" +qa` | optional UI/runtime integrations |
| Verified add-on | `nvim --headless "+checkhealth ts-install" +qa` | Treesitter install/query state |
| Verified add-on | `nvim --headless "+checkhealth fzf-lua-frecency" +qa` | frecency extension wiring |

Current validation on this machine still expects explicit warnings from `lazy` (Lua 5.1 / luarocks), `mason` (optional Composer/PHP/Java/Julia runtimes), `sidekick` (missing optional AI CLIs), `snacks` (headless/renderer-specific features), and `ts-install` (existing local `ecma`, `html_tags`, and `jsx` query issues). Treat those as signal to understand, not noise to hide.

Use `stylua .` when you want to apply formatting instead of only checking it.

After editing `doc/onebeer.txt`, rebuild local help tags with:

```sh
nvim --headless "+helptags doc" +qa
```

The selene linter uses a custom standard library definition (`lua51+vim+onebeer`) to understand Neovim and config-specific globals. Plugin spec files are excluded from the stricter rules.

---

## Neovide

If you run this config inside [Neovide](https://neovide.dev/), a separate settings profile kicks in automatically with:

- Background transparency set to `0.8`
- Cursor trail animation (`0.1`)
- Window size persistence between sessions

No extra config needed — Neovide is detected at startup.

---

You've got everything you need. Go build something great. 🍺
