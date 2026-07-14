---@class onebeer.mule.Process
local M = {}

local config = require("onebeer.mule.config")

---@class onebeer.mule.ProcessOpts
---@field cwd? string
---@field stdin? string

---@param executable_key string
---@param args? string[]
---@return string[]|nil, string|nil
local function command(executable_key, args)
  local cmd = config.command(executable_key, args)
  if cmd == nil then
    return nil, ("missing executable config for %s"):format(executable_key)
  end
  return cmd, nil
end

---@param opts? onebeer.mule.ProcessOpts
---@return vim.SystemOpts
local function system_opts(opts)
  return {
    cwd = opts and opts.cwd or nil,
    stdin = opts and opts.stdin or nil,
    text = true,
  }
end

---@param executable_key string
---@param args? string[]
---@param opts? onebeer.mule.ProcessOpts
---@return vim.SystemCompleted|nil, string|nil
function M.run(executable_key, args, opts)
  local cmd, command_err = command(executable_key, args)
  if cmd == nil then
    return nil, command_err
  end

  local ok, system_obj = pcall(vim.system, cmd, system_opts(opts))
  if not ok then
    return nil, tostring(system_obj)
  end

  return system_obj:wait()
end

---@param executable_key string
---@param args? string[]
---@param opts? onebeer.mule.ProcessOpts
---@param on_exit fun(result: vim.SystemCompleted|nil, err: string|nil)
---@return vim.SystemObj|nil, string|nil
function M.start(executable_key, args, opts, on_exit)
  local completed = false
  local function fail(err)
    if completed then
      return
    end
    completed = true
    on_exit(nil, err)
  end

  local cmd, command_err = command(executable_key, args)
  if cmd == nil then
    fail(command_err)
    return nil, command_err
  end

  local function finish(result)
    if completed then
      return
    end
    completed = true
    vim.schedule(function()
      on_exit(result, nil)
    end)
  end

  local ok, system_obj = pcall(vim.system, cmd, system_opts(opts), finish)
  if not ok then
    local err = tostring(system_obj)
    fail(err)
    return nil, err
  end

  return system_obj, nil
end

return M
