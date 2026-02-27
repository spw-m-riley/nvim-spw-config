---@module "lazy"
---@type LazySpec
return {
  "neovim/nvim-lspconfig",
  ft = "lua",
  config = function()
    vim.lsp.enable("lua_ls")
  end,
}
