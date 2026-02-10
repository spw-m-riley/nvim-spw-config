return {
  "CopilotC-Nvim/CopilotChat.nvim",
  dependencies = {
    { "nvim-lua/plenary.nvim", branch = "master" },
  },
  lazy = false,
  build = "make tiktoken",
  config = true,
  keys = {
    { "<leader>cco", "<cmd>CopilotChat<cr>", desc = "CopilotChat: open chat" },
    { "<leader>cct", "<cmd>CopilotChatToggle<cr>", desc = "CopilotChat: toggle chat" },
    { "<leader>ccm", "<cmd>CopilotChatModels<cr>", desc = "CopilotChat: models" },
  },
}
