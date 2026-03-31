---@module "lazy"
---@type LazySpec
return {
  "matt-riley/waystone.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    slots = 4,
  },
  keys = {
    { "<leader>go", "<cmd>WaystoneList<cr>", desc = "Waystone [O]pen list" },
    {
      "<leader>gt",
      function()
        require("waystone").toggle_file()
      end,
      desc = "Waystone [T]oggle file",
    },
    { "<leader>gT", "<cmd>WaystoneToggle<cr>", desc = "Waystone toggle lis[T]" },
    { "<leader>gs", "<cmd>WaystoneScope<cr>", desc = "Waystone [S]cope" },
    {
      "<leader>gf",
      function()
        require("waystone").cycle_next()
      end,
      desc = "Waystone [F]orward",
    },
    {
      "<leader>gb",
      function()
        require("waystone").cycle_prev()
      end,
      desc = "Waystone [B]ackward",
    },
    { "<leader>g1", "<cmd>WaystoneSelect 1<cr>", desc = "Waystone [1]" },
    { "<leader>g2", "<cmd>WaystoneSelect 2<cr>", desc = "Waystone [2]" },
    { "<leader>g3", "<cmd>WaystoneSelect 3<cr>", desc = "Waystone [3]" },
    { "<leader>g4", "<cmd>WaystoneSelect 4<cr>", desc = "Waystone [4]" },
  },
}
