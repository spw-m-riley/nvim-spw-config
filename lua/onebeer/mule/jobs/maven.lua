---@class onebeer.mule.MavenJob
local M = {}

local detect = require("onebeer.mule.detect")
local diagnostics = require("onebeer.mule.diagnostics")
local maven_output = require("onebeer.mule.parsers.maven_output")
local process = require("onebeer.mule.jobs.process")

---@class onebeer.mule.MavenBuildOpts
---@field path? string
---@field args? string[]
---@field quickfix? boolean

---@param result vim.SystemCompleted
---@param opts onebeer.mule.MavenBuildOpts
---@return boolean, vim.SystemCompleted
local function finalize(result, opts)
  if result.code ~= 0 then
    if opts.quickfix ~= false then
      diagnostics.set_quickfix("Mule Maven Build", maven_output.quickfix_items(result))
    end
    return false, result
  end

  return true, result
end

---@param opts? onebeer.mule.MavenBuildOpts
---@return boolean, vim.SystemCompleted|string
function M.build(opts)
  local options = opts or {}
  local project = detect.project(options.path)
  if project == nil then
    return false, "No Mule project detected"
  end

  local result, err = process.run("maven", options.args or { "package" }, { cwd = project.root })
  if result == nil then
    return false, err or "Failed to start Maven"
  end

  return finalize(result, options)
end

---@param opts? onebeer.mule.MavenBuildOpts
---@param callback fun(ok: boolean, result_or_error: vim.SystemCompleted|string)
---@return vim.SystemObj|nil, string|nil
function M.build_async(opts, callback)
  local options = opts or {}
  local project = detect.project(options.path)
  if project == nil then
    local err = "No Mule project detected"
    callback(false, err)
    return nil, err
  end

  return process.start("maven", options.args or { "package" }, { cwd = project.root }, function(result, err)
    if result == nil then
      callback(false, err or "Failed to start Maven")
      return
    end
    local ok, finalized = finalize(result, options)
    callback(ok, finalized)
  end)
end

return M
