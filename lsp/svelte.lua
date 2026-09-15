---@type vim.lsp.Config
local lsp_settings = require("onebeer.settings.lsp")

return {
  -- Conform owns Svelte formatting through Prettier.
  on_init = lsp_settings.disable_formatting,
}
