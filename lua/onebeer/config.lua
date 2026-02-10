local uv = vim.uv or vim.loop

local DEFAULTS = {
  nopilot_dir = vim.fn.expand("$HOME/Documents/projects/work"),
  user = "matt",
}

local OVERRIDES = {
  nopilot_dir = os.getenv("NOPILOT_DIR"),
}

local function resolve_defaults()
  return vim.tbl_extend("force", {}, DEFAULTS, OVERRIDES)
end

local function normalize(path)
  if vim.fs and type(vim.fs.normalize) == "function" then
    return vim.fs.normalize(path)
  end
  return path
end

local function starts_with(str, prefix)
  return str:sub(1, #prefix) == prefix
end

local function should_enable_copilot(defaults)
  local cwd = normalize((uv and uv.cwd()) or vim.fn.getcwd())
  local nopilot_dir = normalize(vim.fn.expand(defaults.nopilot_dir)):gsub("/+$", "")

  if cwd == nopilot_dir then
    return false
  end

  return not starts_with(cwd, nopilot_dir .. "/")
end

local function should_enable_tabnine(defaults)
  local user = vim.loop.os_get_passwd().username
  local out = user:lower() == defaults.user:lower()
  return out
end

local defaults = resolve_defaults()

---@class OneBeerConfig
---@field copilot boolean
local M = {
  copilot = should_enable_copilot(defaults),
  tabnine = should_enable_tabnine(defaults)
}

return M
