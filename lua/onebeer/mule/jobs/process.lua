---@class onebeer.mule.Process
local M = {}

local config = require("onebeer.mule.config")

---@class onebeer.mule.ProcessOpts
---@field cwd? string
---@field stdin? string

---@param executable_key string
---@param args? string[]
---@param opts? onebeer.mule.ProcessOpts
---@return vim.SystemCompleted|nil, string|nil
function M.run(executable_key, args, opts)
  local cmd = config.command(executable_key, args)
  if cmd == nil then
    return nil, ("missing executable config for %s"):format(executable_key)
  end

  local ok, system_obj = pcall(vim.system, cmd, {
    cwd = opts and opts.cwd or nil,
    stdin = opts and opts.stdin or nil,
    text = true,
  })
  if not ok then
    return nil, system_obj
  end

  return system_obj:wait()
end

return M
