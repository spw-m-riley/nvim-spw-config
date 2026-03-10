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
│   ├── gopls.lua
│   ├── ts_ls.lua
│   ├── lua_ls.lua
│   ├── html.lua
│   ├── terraformls.lua
│   ├── gleam.lua
│   └── actionsls.lua
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

LSP install/curation is managed by [Mason](https://github.com/williamboman/mason.nvim) in `lua/onebeer/plugins/lsp/mason.lua`, with server-specific config files in `lsp/`. The following curated servers are installed and configured:

| Language | Server | Notable features |
|---|---|---|
| Go | `gopls` | Inlay hints, shadow/unused analysis, codelenses (govulncheck, tidy) |
| TypeScript / JavaScript | `ts_ls` | Full inlay hints, import organisation, file operations |
| Lua | `lua_ls` | Neovim API aware, strict workspace scanning limits, formatting off (stylua owns that) |
| JSON | `jsonls` | JSON language features; formatting handled by conform |
| HTML | `html` | — |
| Shell | `bashls` | Shell language features |
| Astro | `astro` | Astro language features; formatting handled by conform |
| Terraform | `terraformls` | — |
| Gleam | `gleam` | — |
| GitHub Actions | `gh_actions_ls` | Workflow file linting |

### Formatting & linting

Formatting is handled by [conform.nvim](https://github.com/stevearc/conform.nvim) — it owns format-on-save for every supported filetype. LSP formatting is intentionally disabled wherever conform has a better tool (e.g. `lua_ls` defers to `stylua`).

The main formatter paths are:

- `stylua` for Lua
- `shfmt` first, `beautysh` fallback for `sh` / `zsh`
- `prettierd` first, `prettier` fallback for JS / TS / web filetypes

Linting runs through [nvim-lint](https://github.com/mfussenegger/nvim-lint) with a split low-latency workflow:

- JS / TS / Astro use `oxlint` on `InsertLeave`, with optional `eslint_d` when it is installed
- JS / TS / Astro use `eslint` on `BufWritePost`
- Markdown / prose use `markdownlint`, `write-good`, and `woke` on save
- Shell / YAML / Terraform / Docker / gitcommit / GitHub Actions use `shellcheck`, `yamllint`, `tflint`, `hadolint`, `gitlint`, and `actionlint`

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

Run `:checkhealth onebeer` to see the status of every external dependency. Missing tools can be auto-installed directly from the health check — it knows the full dependency chain (brew → mise → go → gojson, etc.) and will walk you through it step by step. > If it's your first time setting up, start here.

If you plan to use `octo.nvim`, also make sure `gh auth status` succeeds. Features that touch GitHub Projects v2 may additionally require refreshing your token with the `read:project` scope.

### Local overrides

Create `lua/onebeer/local.lua` for anything machine-specific — fonts, transparency settings, extra keymaps, whatever doesn't belong in version control. It's loaded last and not tracked by git.

---

## Development and linting

When working on the config itself:

```sh
# Lint
selene .

# Check formatting
stylua --check .

# Apply formatting
stylua .

# Validate plugins
nvim --headless "+Lazy! check" +qa

# Full health check
nvim --headless "+checkhealth onebeer" +qa

# Rebuild local help tags after editing doc/onebeer.txt
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
