---@module "lazy"
---@type LazySpec
return {
  "echasnovski/mini.files",
  version = "*",
  event = "VeryLazy",
  opts = {},
  keys = {
    {
      "<leader>f",
      function()
        local files = require("mini.files")
        local buf_name = vim.api.nvim_buf_get_name(0)
        local path = vim.fn.filereadable(buf_name) == 1 and buf_name or vim.fn.getcwd()
        files.open(path)
        files.reveal_cwd()
      end,
      mode = "n",
      desc = "[F]iles",
    },
  },
}
