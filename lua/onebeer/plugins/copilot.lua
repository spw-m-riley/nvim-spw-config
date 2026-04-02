---@type onebeer.PluginSpec
local config = require("onebeer.config")

---@param client vim.lsp.Client
---@param bufnr integer
local function enable_inline_completion(client, bufnr)
  if client.name ~= "copilot" then
    return
  end

  local inline_completion = vim.lsp.inline_completion
  if not inline_completion or type(inline_completion.enable) ~= "function" then
    return
  end

  if client:supports_method(vim.lsp.protocol.Methods.textDocument_inlineCompletion, bufnr) then
    inline_completion.enable(true, { bufnr = bufnr })
  end
end

local function setup_copilot_lsp()
  local group = vim.api.nvim_create_augroup("OneBeerCopilotLsp", { clear = true })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client then
        enable_inline_completion(client, ev.buf)
      end
    end,
  })

  for _, client in ipairs(vim.lsp.get_clients({ name = "copilot" })) do
    for bufnr in pairs(client.attached_buffers or {}) do
      enable_inline_completion(client, bufnr)
    end
  end

  vim.lsp.config("copilot", {})

  if not vim.lsp.is_enabled("copilot") then
    vim.lsp.enable("copilot")
  end
end

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
      server_opts_overrides = {
        settings = {
          nextEditSuggestions = {
            enabled = true,
          },
        },
      },
    })

    setup_copilot_lsp()
  end,
}
