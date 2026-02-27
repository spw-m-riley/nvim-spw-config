local uv = vim.uv or vim.loop

---@class OneBeerConfigDefaults
---@field nopilot_dir string
---@field user string

---@class OneBeerConfigOverrides
---@field nopilot_dir string|nil

---@type OneBeerConfigDefaults
local DEFAULTS = {
  nopilot_dir = vim.fn.expand("$HOME/Documents/projects/work"),
  user = "matt",
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

---@param defaults OneBeerConfigDefaults
---@return boolean
local function should_enable_tabnine(defaults)
  local passwd = (uv and uv.os_get_passwd and uv.os_get_passwd()) or (vim.loop and vim.loop.os_get_passwd and vim.loop.os_get_passwd())
  local user = (passwd and passwd.username) or ""
  local out = user:lower() == defaults.user:lower()
  return out
end

---@type OneBeerConfigDefaults
local defaults = resolve_defaults()

---@class OneBeerConfig
---@field copilot boolean
---@field tabnine boolean
local M = {
  copilot = should_enable_copilot(defaults),
  tabnine = should_enable_tabnine(defaults)
}

return M
