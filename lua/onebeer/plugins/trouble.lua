---@module "lazy"
---@type LazySpec
return {
  "folke/trouble.nvim", -- A pretty diagnostics, references, telescope results, quickfix and location list to help you solve all the trouble your code is causing.
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  event = "VeryLazy",
  opts = {
    auto_close = true,
    auto_preview = true,
    use_diagnostic_signs = true,
    win_config = {
      border = "rounded",
    },
  },
  keys = {
    {
      "<leader>qf",
      "<cmd>Trouble diagnostics toggle<cr>",
      desc = "[Q]uickfix [F]ocus diagnostics",
    },
  },
}
