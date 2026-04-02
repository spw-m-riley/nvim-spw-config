---@type onebeer.PluginSpec
return {
  "NeogitOrg/neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "sindrets/diffview.nvim",
  },
  cmd = "Neogit",
  keys = {
    {
      "<leader>vn",
      "<cmd>Neogit<cr>",
      desc = "[V]CS [N]eogit",
    },
    {
      "<leader>vc",
      "<cmd>Neogit commit<cr>",
      desc = "[V]CS [C]ommit",
    },
    {
      "<leader>vp",
      "<cmd>Neogit push<cr>",
      desc = "[V]CS [P]ush",
    },
    {
      "<leader>vP",
      "<cmd>Neogit pull<cr>",
      desc = "[V]CS [P]ull",
    },
  },
  opts = {
    integrations = {
      diffview = true,
      fzf_lua = true,
    },
    sections = {
      recent = {
        folded = false,
      },
      stashes = {
        folded = true,
      },
    },
    signs = {
      hunk = { "", "" },
      item = { "▸", "▾" },
      section = { "▸", "▾" },
    },
  },
}
