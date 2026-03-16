---@type vim.lsp.Config
local lsp_settings = require("onebeer.settings.lsp")

local server_cmd = lsp_settings.resolve_executable("rust-analyzer") or "rust-analyzer"

return {
  cmd = { server_cmd },
  settings = {
    ["rust-analyzer"] = {
      cargo = {
        buildScripts = {
          enable = true,
        },
      },
      check = {
        command = "clippy",
      },
      procMacro = {
        enable = true,
      },
    },
  },
  -- Conform owns Rust formatting; prevent rust-analyzer from competing.
  on_init = lsp_settings.disable_formatting,
}
