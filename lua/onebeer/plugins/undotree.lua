---@module "lazy"
---@type LazySpec
return {
  "mbbill/undotree",
  cmd = "UndotreeToggle",
  keys = {
    {
      "<leader>uu",
      "<cmd>UndotreeToggle<cr>",
      desc = "[U]ndo [U]ndo tree",
    },
  },
  config = function()
    vim.g.undotree_WindowLayout = 2
    vim.g.undotree_ShortIndicators = 1
    vim.g.undotree_SetFocusWhenToggle = 1
  end,
}
