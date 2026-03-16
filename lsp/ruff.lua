---@type vim.lsp.Config
local lsp_settings = require("onebeer.settings.lsp")

local ruff_cmd = lsp_settings.resolve_executable("ruff") or "ruff"

return {
  cmd = { ruff_cmd, "server" },
  filetypes = { "python" },
  root_markers = {
    "ruff.toml",
    ".ruff.toml",
    "pyproject.toml",
    "pyrightconfig.json",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "Pipfile",
    ".git",
  },
  on_attach = function(client)
    if client.server_capabilities then
      client.server_capabilities.hoverProvider = false
    end
  end,
  -- Conform owns formatting; prevent Ruff from competing directly.
  on_init = lsp_settings.disable_formatting,
}
