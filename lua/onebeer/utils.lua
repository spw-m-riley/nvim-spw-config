---@class onebeer.utils
local M = {}

---Print and return value (for debugging)
---@param v any
---@return any
local function P(v)
  print(vim.inspect(v))
  return v
end

---Reload a module using plenary
---@param ... string
---@return any
local function RELOAD(...)
  return require("plenary.reload").reload_module(...)
end

---Reload and require a module
---@param name string
---@return any
local function R(name)
  RELOAD(name)
  return require(name)
end

M.P = P
M.RELOAD = RELOAD
M.R = R

_G.P = P
_G.RELOAD = RELOAD
_G.R = R

---Safely require a module with error handling
---@param module string
---@param level? integer vim.log.levels
---@return boolean, any
M.safe_require = function(module, level)
  local ok, result = pcall(require, module)
  if not ok then
    vim.notify(
      "Failed to load " .. module .. ": " .. tostring(result),
      level or vim.log.levels.WARN,
      { title = "Config Error" }
    )
  end
  return ok, result
end

---Set a keymap with sensible defaults
---@param mode string|string[]
---@param key string
---@param cmd string|function
---@param opts? vim.keymap.set.Opts
M.map = function(mode, key, cmd, opts)
  local opt = vim.tbl_extend("force", { noremap = true, silent = true }, opts)
  vim.keymap.set(mode, key, cmd, opt)
end

---Create a keymap command string
---@param command string
---@return string
M.keymap_cmd = function(command)
  return table.concat({ "<CMD>", command, "<CR>" })
end

---Set a normal mode keymap with leader prefix
---@param suffix string
---@param rhs string|function
---@param desc string
M.nmap_leader = function(suffix, rhs, desc)
  M.map("n", "<Leader>" .. suffix, rhs, { desc = desc })
end

return M
