---@class onebeer.mule.MUnitJob
local M = {}

local detect = require("onebeer.mule.detect")
local diagnostics = require("onebeer.mule.diagnostics")
local maven_output = require("onebeer.mule.parsers.maven_output")
local process = require("onebeer.mule.jobs.process")

---@class onebeer.mule.MUnitTest
---@field name string
---@field path string
---@field line integer
---@field suite string

---@param path string
---@return string
local function fallback_suite_name(path)
  return vim.fn.fnamemodify(path, ":t:r")
end

---@param path string
---@return string
function M.suite_selector(path)
  local project = detect.project(path)
  if project == nil then
    return fallback_suite_name(path)
  end

  local relative = vim.fs.relpath(project.munit_dir, path)
  if relative == nil or vim.startswith(relative, "..") then
    return fallback_suite_name(path)
  end

  return relative:gsub("\\", "/"):gsub("%.xml$", "")
end

---@param path string
---@return onebeer.mule.MUnitTest[]
function M.discover_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return {}
  end

  local tests = {}
  for line_number, line in ipairs(lines) do
    for name in line:gmatch("<munit:test%s+[^>]-name=[\"']([^\"']+)") do
      tests[#tests + 1] = {
        line = line_number,
        name = name,
        path = path,
        suite = M.suite_selector(path),
      }
    end
  end
  return tests
end

---@param path string
---@return onebeer.mule.MUnitTest[]
function M.discover(path)
  local project = detect.project(path)
  if project == nil then
    return {}
  end

  local files = vim.fn.glob(project.munit_dir .. "/**/*.xml", false, true)
  table.sort(files)

  local tests = {}
  for _, file in ipairs(files) do
    vim.list_extend(tests, M.discover_file(file))
  end
  return tests
end

---@param path string
---@param line integer
---@return onebeer.mule.MUnitTest|nil
function M.nearest(path, line)
  local nearest
  for _, test in ipairs(M.discover_file(path)) do
    if test.line <= line then
      nearest = test
    end
  end
  return nearest
end

---@param test onebeer.mule.MUnitTest
---@return string
function M.selector(test)
  return ("%s#%s"):format(test.suite, test.name)
end

---@class onebeer.mule.MUnitRunOpts
---@field path? string
---@field selector? string
---@field quickfix? boolean

---@param result vim.SystemCompleted
---@param opts onebeer.mule.MUnitRunOpts
---@return boolean, vim.SystemCompleted
local function finalize(result, opts)
  if result.code ~= 0 then
    if opts.quickfix ~= false then
      diagnostics.set_quickfix("Mule MUnit", maven_output.quickfix_items(result))
    end
    return false, result
  end

  return true, result
end

---@param opts? onebeer.mule.MUnitRunOpts
---@return boolean, vim.SystemCompleted|string
function M.run(opts)
  local options = opts or {}
  local project = detect.project(options.path)
  if project == nil then
    return false, "No Mule project detected"
  end

  local args = { "clean", "test" }
  if options.selector and options.selector ~= "" then
    args[#args + 1] = "-Dmunit.test=" .. options.selector
  end

  local result, err = process.run("maven", args, { cwd = project.root })
  if result == nil then
    return false, err or "Failed to start Maven"
  end

  return finalize(result, options)
end

---@param opts? onebeer.mule.MUnitRunOpts
---@param callback fun(ok: boolean, result_or_error: vim.SystemCompleted|string)
---@return vim.SystemObj|nil, string|nil
function M.run_async(opts, callback)
  local options = opts or {}
  local project = detect.project(options.path)
  if project == nil then
    local err = "No Mule project detected"
    callback(false, err)
    return nil, err
  end

  local args = { "clean", "test" }
  if options.selector and options.selector ~= "" then
    args[#args + 1] = "-Dmunit.test=" .. options.selector
  end

  return process.start("maven", args, { cwd = project.root }, function(result, err)
    if result == nil then
      callback(false, err or "Failed to start Maven")
      return
    end
    local ok, finalized = finalize(result, options)
    callback(ok, finalized)
  end)
end

return M
