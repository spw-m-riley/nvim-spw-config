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

  if result.code ~= 0 then
    if options.quickfix ~= false then
      diagnostics.set_quickfix("Mule Maven Build", maven_output.quickfix_items(result))
    end
    return false, result
  end

  return true, result
end

return M
