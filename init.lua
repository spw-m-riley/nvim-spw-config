---@module "onebeer.init"
---@brief [[
---OneBeer Neovim entrypoint that wires base settings, plugins, and local overrides.
---@brief ]]
vim.loader.enable()
require("onebeer.utils")

local uv = vim.uv or vim.loop
local safe_require = require("onebeer.utils").safe_require

-- Load settings
local ok, settings = safe_require("onebeer.settings")
if ok then
  if vim.g.neovide then
    settings.neovide()
  else
    settings.defaults()
  end
end

safe_require("onebeer.settings.diagnostics")
safe_require("onebeer.settings.lsp")
local ok_config, config = safe_require("onebeer.config")
if ok_config then
  vim.g.onebeer = config
end
safe_require("onebeer.lazy")
safe_require("onebeer.autocmds")
safe_require("onebeer.tools.commands")

local local_config = vim.fn.stdpath("config") .. "/lua/onebeer/local.lua"
if uv.fs_stat(local_config) then
  safe_require("onebeer.local", vim.log.levels.DEBUG)
end
