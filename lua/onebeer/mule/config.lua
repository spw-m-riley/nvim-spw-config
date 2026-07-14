---@class onebeer.mule.Config
---@field fixture_root? string
---@field fixture_bin_root? string
---@field executables? table<string, string|string[]>

local M = {}

local module_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")

---@type onebeer.mule.Config
local defaults = {
  fixture_root = module_root .. "/fixtures",
  fixture_bin_root = module_root .. "/fixtures/bin",
  executables = {
    anypoint = "anypoint-cli-v4",
    dw = "dw",
    harness_fail = module_root .. "/fixtures/bin/smoke-fail",
    harness_ok = module_root .. "/fixtures/bin/smoke-ok",
    maven = "mvn",
  },
}

---@type onebeer.mule.Config
local options = vim.deepcopy(defaults)

---@param opts? onebeer.mule.Config
---@return onebeer.mule.Config
function M.setup(opts)
  options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  return options
end

---@return onebeer.mule.Config
function M.get()
  return options
end

---@param name string
---@return string|string[]|nil
function M.executable(name)
  return options.executables and options.executables[name] or nil
end

---@param name string
---@param extra_args? string[]
---@return string[]|nil
function M.command(name, extra_args)
  local executable = M.executable(name)
  if executable == nil then
    return nil
  end

  local command
  if type(executable) == "table" then
    command = vim.deepcopy(executable)
  elseif executable ~= "" then
    command = { executable }
  end

  if command == nil or command[1] == nil then
    return nil
  end

  if extra_args ~= nil then
    vim.list_extend(command, extra_args)
  end

  return command
end

---@param name string
---@return string|nil
function M.command_name(name)
  local command = M.command(name)
  return command and command[1] or nil
end

---@return string
function M.fixture_root()
  local fixture_root = assert(options.fixture_root, "missing Mule fixture root")
  return fixture_root
end

---@return string
function M.fixture_bin_root()
  local fixture_bin_root = assert(options.fixture_bin_root, "missing Mule fixture bin root")
  return fixture_bin_root
end

---@generic T
---@param opts onebeer.mule.Config
---@param fn fun(): T
---@return T
function M.with(opts, fn)
  local previous = vim.deepcopy(options)
  M.setup(vim.tbl_deep_extend("force", vim.deepcopy(options), opts))
  local ok, result = pcall(fn)
  options = previous
  if not ok then
    error(result, 2)
  end
  return result
end

return M
