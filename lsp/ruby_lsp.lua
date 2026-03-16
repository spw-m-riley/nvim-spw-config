---@class RubyLspRuntimeConfig : vim.lsp.Config

local lsp_settings = require("onebeer.settings.lsp")

---@return string
local function resolve_server_cmd()
  local server_cmd = vim.fn.exepath("ruby-lsp")
  if server_cmd ~= "" then
    return server_cmd
  end

  -- Ruby LSP should run inside the active Ruby environment rather than a Mason gem install.
  return "ruby-lsp"
end

---@param client vim.lsp.Client
local function disable_formatting(client)
  lsp_settings.disable_formatting(client)

  if not client or not client.server_capabilities then
    return
  end

  client.server_capabilities.documentOnTypeFormattingProvider = nil
end

---@param dispatchers vim.lsp.rpc.Dispatchers
---@param config RubyLspRuntimeConfig?
local function start_ruby_lsp(dispatchers, config)
  local root_dir = config and config.root_dir or nil

  return vim.lsp.rpc.start({ resolve_server_cmd() }, dispatchers, root_dir and { cwd = root_dir } or nil)
end

---@param client vim.lsp.Client
---@param config RubyLspRuntimeConfig
---@return boolean
local function reuse_client(client, config)
  return client.config.root_dir == config.root_dir
end

---@type vim.lsp.Config
return {
  cmd = start_ruby_lsp,
  filetypes = { "ruby", "eruby" },
  root_markers = {
    "Gemfile",
    "gems.rb",
    ".ruby-version",
    ".tool-versions",
    "mise.toml",
    ".git",
  },
  init_options = {
    formatter = "none",
    enabledFeatures = {
      formatting = false,
      onTypeFormatting = false,
    },
  },
  on_init = disable_formatting,
  reuse_client = reuse_client,
}
