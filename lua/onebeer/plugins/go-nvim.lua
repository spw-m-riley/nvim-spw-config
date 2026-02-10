---@module "lazy"
---@type LazySpec
return {
  "ray-x/go.nvim",
  dependencies = { -- optional packages
    "ray-x/guihua.lua",
    "neovim/nvim-lspconfig",
    "nvim-treesitter/nvim-treesitter",
  },
  opts = {
    goimport = "goimports", -- goimport command, can be gopls or goimport
    gofmt = "gofmt", -- gofmt command, can be gofumpt
    -- max_line_len = 120, -- max line length in golines format
    lsp_keymaps = false, -- disable default keymaps for lsp
    lsp_gofumpt = true, -- use gofumpt instead of gofmt
    lsp_inlay_hints = {
      enable = true,
    },
    luasnip = true, -- use luasnip for autocompletion
  },
  config = function(_, opts)
    -- -- Patch go.gopls to remove invalid settings before they're applied to gopls
    -- local gopls_module = require("go.gopls")
    -- local orig_setups = gopls_module.setups
    -- gopls_module.setups = function()
    --   local setups = orig_setups()
    --   if setups and setups.settings and setups.settings.gopls then
    --     -- Remove invalid gopls settings
    --     setups.settings.gopls.diagnosticsTrigger = nil
    --     setups.settings.gopls.semanticTokenTypes = nil
    --     setups.settings.gopls.semanticTokenModifiers = nil
    --   end
    --   return setups
    -- end
    --
    require("go").setup(opts)
  end,
  event = { "CmdlineEnter" },
  ft = { "go", "gomod", "templ" },
  build = ':lua require("go.install").update_all_sync()', -- if you need to install/update all binaries
}
