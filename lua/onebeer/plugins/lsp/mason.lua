---@module "lazy"
---@type LazySpec
return {
  "mason-org/mason-lspconfig.nvim",
  opts = {
    ensure_installed = {
      "gopls",
      "gh_actions_ls",
      "html",
      "terraformls",
      "lua_ls",
      "ts_ls",
    },
  },
  event = "FileType",
  dependencies = {
    {
      "mason-org/mason.nvim",
      opts = {
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          },
        },
      },
      cmd = { "Mason" },
    },
    {
      "antosha417/nvim-lsp-file-operations",
      config = true,
    },
    "neovim/nvim-lspconfig",
  },
}
