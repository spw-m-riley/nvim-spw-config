---@type vim.lsp.Config
-- Prefer a workspace-local TypeScript SDK; fall back to the one bundled with
-- the Mason astro-language-server package so the server can always start even
-- outside a TypeScript project.
local lsp_settings = require("onebeer.settings.lsp")
local mason_tsdk = vim.fn.stdpath("data") .. "/mason/packages/astro-language-server/node_modules/typescript/lib"

---@param root_dir string|nil
---@return string
local function resolve_tsdk(root_dir)
  local current = root_dir
  while current and current ~= "" do
    local candidate = vim.fs.joinpath(current, "node_modules", "typescript", "lib")
    if vim.fn.isdirectory(candidate) == 1 then
      return candidate
    end

    local parent = vim.fs.dirname(current)
    if parent == current then
      break
    end
    current = parent
  end

  return mason_tsdk
end

return {
  init_options = {
    typescript = {
      tsdk = mason_tsdk,
    },
  },
  ---@param new_config vim.lsp.Config
  ---@param root_dir string
  on_new_config = function(new_config, root_dir)
    new_config.init_options = new_config.init_options or {}
    new_config.init_options.typescript = new_config.init_options.typescript or {}
    new_config.init_options.typescript.tsdk = resolve_tsdk(root_dir)
  end,
  -- Conform owns Astro formatting; prevent astro-ls from competing.
  on_init = lsp_settings.disable_formatting,
}
