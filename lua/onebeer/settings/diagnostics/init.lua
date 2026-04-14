---@module "onebeer.settings.diagnostics"
---@type OneBeerIcons
local icons = require("onebeer.settings.icons")

---@type vim.diagnostic.Opts
local diagnostics_config = {
  underline = true,
  update_in_insert = false,
  virtual_text = false,
  virtual_lines = {
    current_line = true,
  },
  severity_sort = true,
  signs = icons.get_diagnostic_signs(),
  float = {
    border = "rounded",
  },
}

vim.diagnostic.config(diagnostics_config)
