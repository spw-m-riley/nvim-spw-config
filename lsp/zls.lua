---@type vim.lsp.Config
local lsp_settings = require("onebeer.settings.lsp")

---@param root_dir string|nil
---@return string[]
local function resolve_zls_cmd(root_dir)
  local zls = lsp_settings.resolve_executable("zls") or "zls"
  if root_dir and root_dir ~= "" then
    local config_path = vim.fs.joinpath(root_dir, "zls.json")
    if vim.fn.filereadable(config_path) == 1 then
      return { zls, "--config-path", config_path }
    end
  end

  return { zls }
end

return {
  cmd = resolve_zls_cmd(),
  filetypes = { "zig", "zir" },
  root_markers = { "zls.json", "build.zig", ".git" },
  before_init = function(_, config)
    config.cmd = resolve_zls_cmd(config.root_dir)
  end,
  workspace_required = false,
}
