---@type vim.lsp.Config
local lsp_settings = require("onebeer.settings.lsp")

return {
  settings = {
    json = {
      validate = { enable = true },
    },
  },
  -- Conform owns JSON formatting; prevent jsonls from competing.
  on_init = lsp_settings.disable_formatting,
}
