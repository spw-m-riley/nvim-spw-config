---@type vim.lsp.Config
local lemminx = require("onebeer.mule.integrations.lemminx")

return {
  root_dir = lemminx.root_dir,
  before_init = function(_, config)
    config.settings = vim.tbl_deep_extend("force", config.settings or {}, lemminx.settings_for_root(config.root_dir))
  end,
}
