---@type onebeer.PluginSpec
return {
  "folke/persistence.nvim",
  event = "BufReadPre",
  opts = {
    options = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" },
  },
  keys = {
    {
      "<leader>qs",
      function()
        require("persistence").load()
      end,
      desc = "[Q]uick restore [S]ession",
    },
    {
      "<leader>qS",
      function()
        require("persistence").load({ last = true })
      end,
      desc = "[Q]uick restore last [S]ession",
    },
    {
      "<leader>qd",
      function()
        require("persistence").stop()
        vim.notify("Session saving disabled for this workspace")
      end,
      desc = "[Q]uick [D]isable session save",
    },
  },
}
