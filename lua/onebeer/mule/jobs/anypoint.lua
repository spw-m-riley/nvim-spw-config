---@class onebeer.mule.AnypointJob
local M = {}

local config = require("onebeer.mule.config")
local process = require("onebeer.mule.jobs.process")

---@return boolean, string|nil
local function ensure_cli()
  local executable = config.command_name("anypoint")
  if executable and vim.fn.executable(executable) == 1 then
    return true, nil
  end
  return false, ("Anypoint CLI v4 `%s` is not executable"):format(executable or "anypoint-cli-v4")
end

---@param text string
---@return boolean
local function is_auth_failure(text)
  local lowered = text:lower()
  return lowered:find("401", 1, true) ~= nil
    or lowered:find("403", 1, true) ~= nil
    or lowered:find("unauthorized", 1, true) ~= nil
    or lowered:find("forbidden", 1, true) ~= nil
    or lowered:find("login", 1, true) ~= nil
end

---@param result vim.SystemCompleted
---@return table
local function classify_failure(result)
  local output = vim.trim((result.stderr or "") .. "\n" .. (result.stdout or ""))
  return {
    kind = is_auth_failure(output) and "auth" or "command",
    message = output ~= "" and output or ("Anypoint CLI exited with " .. result.code),
  }
end

---@class onebeer.mule.AnypointRunOpts
---@field json? boolean

---@param args string[]
---@param opts? onebeer.mule.AnypointRunOpts
---@return boolean, any
function M.run(args, opts)
  local available, err = ensure_cli()
  if not available then
    return false, {
      kind = "missing",
      message = err,
    }
  end

  local result, run_err = process.run("anypoint", args)
  if result == nil then
    return false, {
      kind = "start",
      message = run_err or "Failed to start Anypoint CLI",
    }
  end

  if result.code ~= 0 then
    return false, classify_failure(result)
  end

  if opts and opts.json then
    local ok, decoded = pcall(vim.json.decode, result.stdout or "")
    if ok then
      return true, decoded
    end
  end

  return true, result.stdout or ""
end

return M
