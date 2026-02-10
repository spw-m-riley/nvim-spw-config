---@module "lazy"
---@type LazySpec
local config = require("onebeer.config")

return {
  "zbirenbaum/copilot.lua",
  enabled = function()
    return config.copilot
  end,
  event = "BufReadPre",
  cmd = "Copilot",
  dependencies = {
    { "copilotlsp-nvim/copilot-lsp" },
  },
  keys = {
    { "<leader>cp", "<cmd>Copilot panel<cr>", desc = "[C]opilot [P]anel" },
  },
  config = function()
    vim.defer_fn(function()
      require("copilot").setup({
        suggestion = {
          enabled = false,
          auto_trigger = false,
          keymap = {
            accept = "<C-A>",
            accept_word = false,
            next = "<C-X>",
            prev = "<C-C>",
            dismiss = "<C-S>",
          },
        },
        panel = { enabled = true },
        nes = {
          enabled = false,
          keymap = {
            accept_and_goto = false,
            accept = false,
            dismiss = false,
          },
        },
      })
    end, 100)
  end,
}
