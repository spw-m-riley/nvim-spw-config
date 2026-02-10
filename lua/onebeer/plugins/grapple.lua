---@module "lazy"
---@type LazySpec
return {
  "cbochs/grapple.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    scope = "git",
    statusline = {
      icon = "󰛢",
      active = "|%s|",
      inactive = " %s ",
    },
  },
  keys = {
    { "<leader>go", "<cmd>Grapple open_tags<cr>", desc = "[G]rapple [O]pen tags" },
    { "<leader>gt", "<cmd>Grapple toggle<cr>", desc = "[G]rapple toggle [T]ag" },
    { "<leader>gT", "<cmd>Grapple toggle_tags<cr>", desc = "[G]rapple toggle [T]ags" },
    { "<leader>gs", "<cmd>Grapple toggle_scopes<cr>", desc = "[G]rapple toggle [S]copes" },
    { "<leader>gf", "<cmd>Grapple cycle forward<cr>", desc = "[G]rapple [F]orward" },
    { "<leader>gb", "<cmd>Grapple cycle backward<cr>", desc = "[G]rapple [B]ackward" },
    { "<leader>g1", "<cmd>Grapple select index=1<cr>", desc = "[G]rapple select [1]" },
    { "<leader>g2", "<cmd>Grapple select index=2<cr>", desc = "[G]rapple select [2]" },
    { "<leader>g3", "<cmd>Grapple select index=3<cr>", desc = "[G]rapple select [3]" },
    { "<leader>g4", "<cmd>Grapple select index=4<cr>", desc = "[G]rapple select [4]" },
  },
}
