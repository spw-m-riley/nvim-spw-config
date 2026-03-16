---@type vim.lsp.Config
local lsp_settings = require("onebeer.settings.lsp")

return {
  filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab", "yaml.helm-values" },
  settings = {
    redhat = {
      telemetry = {
        enabled = false,
      },
    },
    yaml = {
      keyOrdering = false,
      validate = true,
      schemaStore = {
        enable = true,
        url = "https://www.schemastore.org/api/json/catalog.json",
      },
      format = {
        enable = false,
      },
    },
  },
  -- Conform owns YAML formatting; prevent yamlls from competing.
  on_init = lsp_settings.disable_formatting,
}
