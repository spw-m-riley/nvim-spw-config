---@type onebeer.PluginSpec
return {
  "pwntester/octo.nvim",
  cmd = "Octo",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "ibhagwan/fzf-lua",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    picker = "fzf-lua",
    enable_builtin = true,
    use_local_fs = false,
  },
  keys = {
    { "<leader>oi", "<cmd>Octo issue list<cr>", desc = "GitHub [I]ssues" },
    { "<leader>op", "<cmd>Octo pr list<cr>", desc = "GitHub [P]ull requests" },
    { "<leader>od", "<cmd>Octo discussion list<cr>", desc = "GitHub [D]iscussions" },
    { "<leader>on", "<cmd>Octo notification list<cr>", desc = "GitHub [N]otifications" },
  },
}
