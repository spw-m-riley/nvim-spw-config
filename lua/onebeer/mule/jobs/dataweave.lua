---@class onebeer.mule.DataWeaveJob
local M = {}

local config = require("onebeer.mule.config")
local dataweave_parser = require("onebeer.mule.parsers.dataweave")
local diagnostics = require("onebeer.mule.diagnostics")
local process = require("onebeer.mule.jobs.process")

---@return boolean, string|nil
local function ensure_dw()
  local executable = config.command_name("dw")
  if executable and vim.fn.executable(executable) == 1 then
    return true, nil
  end
  return false, ("DataWeave CLI `%s` is not executable"):format(executable or "dw")
end

---@param path string
---@return boolean, vim.SystemCompleted|string
function M.validate_file(path)
  local available, err = ensure_dw()
  if not available then
    return false, err
  end

  local result, run_err = process.run("dw", { "validate", path })
  if result == nil then
    return false, run_err or "Failed to start DataWeave CLI"
  end

  if result.code ~= 0 then
    diagnostics.set_quickfix("Mule DataWeave", dataweave_parser.quickfix_items(result, path))
    return false, result
  end

  return true, result
end

---@param path string
---@return boolean, vim.SystemCompleted|string
function M.run_file(path)
  local available, err = ensure_dw()
  if not available then
    return false, err
  end

  local project = require("onebeer.mule.detect").project(path)
  local result, run_err = process.run("dw", { "run", path }, { cwd = project and project.root or nil })
  if result == nil then
    return false, run_err or "Failed to start DataWeave CLI"
  end

  if result.code ~= 0 then
    diagnostics.set_quickfix("Mule DataWeave", dataweave_parser.quickfix_items(result, path))
    return false, result
  end

  return true, result
end

return M
