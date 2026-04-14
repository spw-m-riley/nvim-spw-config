local uv = vim.uv

---@class OneBeerConfigDefaults
---@field nopilot_dir string

---@class OneBeerConfigOverrides
---@field nopilot_dir string|nil

---@type OneBeerConfigDefaults
local DEFAULTS = {
  nopilot_dir = vim.fn.expand("$HOME/Documents/projects/work"),
}

---@type OneBeerConfigOverrides
local OVERRIDES = {
  nopilot_dir = os.getenv("NOPILOT_DIR"),
}

---@return OneBeerConfigDefaults
local function resolve_defaults()
  return vim.tbl_extend("force", {}, DEFAULTS, OVERRIDES)
end

---@param path string
---@return string
local function normalize(path)
  if vim.fs and type(vim.fs.normalize) == "function" then
    return vim.fs.normalize(path)
  end
  return path
end

---@param str string
---@param prefix string
---@return boolean
local function starts_with(str, prefix)
  return str:sub(1, #prefix) == prefix
end

---@param defaults OneBeerConfigDefaults
---@return boolean
local function should_enable_copilot(defaults)
  local cwd = normalize((uv and uv.cwd()) or vim.fn.getcwd())
  local nopilot_dir = normalize(vim.fn.expand(defaults.nopilot_dir)):gsub("/+$", "")

  if cwd == nopilot_dir then
    return false
  end

  return not starts_with(cwd, nopilot_dir .. "/")
end

---@type OneBeerConfigDefaults
local defaults = resolve_defaults()

---@class OneBeerConfig
---@field copilot boolean
local M = {
  copilot = should_enable_copilot(defaults),
}

return M
