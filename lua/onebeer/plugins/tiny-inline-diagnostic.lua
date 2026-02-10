---@module "lazy"
---@type LazySpec
return {
  "rachartier/tiny-inline-diagnostic.nvim",
  event = "VeryLazy",
  keys = {
    {
      "<leader>cd",
      function()
        local inline_enabled = vim.g.onebeer_inline_diagnostics_enabled ~= false
        local tiny = require("tiny-inline-diagnostic")
        if inline_enabled then
          tiny.disable()
          vim.diagnostic.config({
            virtual_text = {
              prefix = "",
              spacing = 2,
              source = "if_many",
            },
          })
        else
          tiny.enable()
          vim.diagnostic.config({ virtual_text = false })
        end
        vim.g.onebeer_inline_diagnostics_enabled = not inline_enabled
      end,
      desc = "[C]ode [D]iagnostics toggle",
    },
  },
  config = function()
    require("tiny-inline-diagnostic").setup()
    vim.diagnostic.config({ virtual_text = false })
    vim.g.onebeer_inline_diagnostics_enabled = true
  end,
}
