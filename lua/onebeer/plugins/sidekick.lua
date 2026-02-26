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
      watch = true, -- auto-reload files changed by Copilot
      mux = {
        backend = "tmux",
        enabled = false,
      },
      picker = "fzf-lua",
      win = {
        layout = "right",
        split = {
          width = 100, -- wider for better readability
        },
      },
      -- Copilot-specific prompts
      prompts = {
        -- Code understanding
        explain = "Explain {selection|this} in {file} around line {line}.",
        explain_error = "Explain this error and how to fix it:\n{selection}",
        -- Code improvement
        fix = "Fix the diagnostics in {file}:\n{diagnostics}",
        refactor = "Refactor {selection|this} for better readability and maintainability.",
        optimize = "Optimize {selection|this} for performance.",
        -- Code generation
        tests = "Write comprehensive tests for {selection|this}.",
        docs = "Add documentation comments to {selection|this}.",
        types = "Add or improve TypeScript/type annotations for {selection|this}.",
        -- Review
        review = "Review {file} for bugs, security issues, and improvements.\n{diagnostics_all}",
        review_selection = "Review {selection} for potential issues.",
        -- Quick context
        buffers = "{buffers}",
        file = "{file}",
        quickfix = "{quickfix}",
      },
    },
  },
  lazy = false,
  keys = {
    -- Toggle Copilot CLI
    {
      "<leader>aa",
      function()
        require("sidekick.cli").toggle({ name = "copilot", focus = true })
      end,
      desc = "Toggle Copilot",
      mode = { "n", "v" },
    },
    -- Prompt picker
    {
      "<leader>ap",
      function()
        require("sidekick.cli").prompt()
      end,
      desc = "Copilot Prompts",
      mode = { "n", "v" },
    },
    -- Quick actions (visual mode sends selection)
    {
      "<leader>ae",
      function()
        require("sidekick.cli").run({ name = "copilot", prompt = "explain" })
      end,
      desc = "Explain code",
      mode = { "n", "v" },
    },
    {
      "<leader>af",
      function()
        require("sidekick.cli").run({ name = "copilot", prompt = "fix" })
      end,
      desc = "Fix diagnostics",
      mode = { "n", "v" },
    },
    {
      "<leader>at",
      function()
        require("sidekick.cli").run({ name = "copilot", prompt = "tests" })
      end,
      desc = "Write tests",
      mode = { "n", "v" },
    },
    {
      "<leader>ar",
      function()
        require("sidekick.cli").run({ name = "copilot", prompt = "review" })
      end,
      desc = "Review file",
      mode = { "n", "v" },
    },
    {
      "<leader>ao",
      function()
        require("sidekick.cli").run({ name = "copilot", prompt = "refactor" })
      end,
      desc = "Refactor code",
      mode = { "n", "v" },
    },
  },
}
