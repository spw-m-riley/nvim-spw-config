---@type vim.lsp.Config
return {
  settings = {
    json = {
      validate = { enable = true },
    },
  },
  -- Conform owns JSON formatting; prevent jsonls from competing.
  on_init = function(client)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
}
