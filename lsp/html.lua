---@class HtmlConfig
---@field capabilities table

---@type table
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

---@type HtmlConfig
return {
  capabilities = capabilities,
}
