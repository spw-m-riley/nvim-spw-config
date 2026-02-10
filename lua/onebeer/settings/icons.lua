---Icon definitions for UI elements and diagnostics
---@class OneBeerDiagnosticsIconMap
---@field Error string
---@field Warn string
---@field Info string
---@field Hint string

---@class OneBeerIcons
---@field diagnostics OneBeerDiagnosticsIconMap
local M = {
  diagnostics = {
    Error = " ",
    Warn = " ",
    Info = " ",
    Hint = "󰋗 ",
  },
}

---Get diagnostic sign configuration for vim.diagnostic.config
---@return {text: table<integer, string>}
function M.get_diagnostic_signs()
  local severity = vim.diagnostic.severity
  return {
    text = {
      [severity.ERROR] = M.diagnostics.Error,
      [severity.HINT] = M.diagnostics.Hint,
      [severity.INFO] = M.diagnostics.Info,
      [severity.WARN] = M.diagnostics.Warn,
    },
  }
end

return M
