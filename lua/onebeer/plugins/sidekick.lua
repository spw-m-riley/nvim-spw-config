---@module "lazy"
---@type LazySpec
local config = require("onebeer.config")

return {
  "folke/sidekick.nvim",
  enabled = function()
    return config.copilot
  end,
  opts = {
    cli = {
      mux = {
        backend = "tmux",
        enabled = false,
      },
      picker = "fzf-lua",
      prompts = {
        explain_block = "Explain {selection|this} in {file} around line {line}.",
        fix_diagnostics = "Fix the diagnostics reported in {file}:\n{diagnostics}",
        review_file = "Review {file} for potential improvements and summarize issues.\n{diagnostics_all}",
        write_tests = "Write thorough tests for {selection|this}.",
      },
    },
  },
  lazy = false,
  keys = {
    {
      "<leader>aa",
      function()
        require("sidekick.cli").toggle({ name = "copilot", focus = true })
      end,
      desc = "Toggle Sidekick (Copilot)",
      mode = { "n", "v" },
    },
    {
      "<leader>ap",
      function()
        require("sidekick.cli").prompt()
      end,
      desc = "Sidekick Prompt Library",
      mode = { "n", "v" },
    },
    {
      "<leader>ay",
      function()
        require("sidekick").nes_jump_or_apply()
      end,
      desc = "Sidekick: goto/apply next edit",
    },
  },
}
