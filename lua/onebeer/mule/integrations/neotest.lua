---@class onebeer.mule.NeotestIntegration
local M = {}

local config = require("onebeer.mule.config")
local detect = require("onebeer.mule.detect")
local munit = require("onebeer.mule.jobs.munit")
local surefire = require("onebeer.mule.parsers.surefire")

---@param path string
---@return boolean
local function is_munit_file(path)
  return path:match("/src/test/munit/.+%.xml$") ~= nil and detect.project(path) ~= nil
end

---@param test onebeer.mule.MUnitTest
---@return table|nil
local function build_spec_for_test(test)
  local command = config.command("maven", {
    "clean",
    "test",
    "-Dmunit.test=" .. munit.selector(test),
  })
  if command == nil then
    return nil
  end

  local project = detect.project(test.path)
  return {
    command = command,
    context = {
      strategy_supported = false,
    },
    cwd = project and project.root or vim.fn.getcwd(),
  }
end

---@param path string
---@param result onebeer.mule.TestResult
---@return string
local function result_id(path, result)
  return ("%s::%s#%s"):format(path, result.classname, result.name)
end

---@param report_path string
---@param result onebeer.mule.TestResult
---@return string|nil
local function munit_path_for_result(report_path, result)
  local project = detect.project(report_path)
  if project == nil or result.classname == "" then
    return nil
  end
  return ("%s/%s.xml"):format(project.munit_dir, result.classname)
end

---@param result onebeer.mule.TestResult
---@return string
local function selector_id(result)
  return ("%s#%s"):format(result.classname, result.name)
end

---@param path string
---@return table[]|nil
local function munit_positions(path)
  if not is_munit_file(path) then
    return nil
  end

  local tests = munit.discover_file(path)
  if tests[1] == nil then
    return nil
  end

  local positions = {
    {
      id = path,
      name = vim.fn.fnamemodify(path, ":t"),
      path = path,
      range = { 0, 0, tests[#tests].line - 1, 0 },
      type = "file",
    },
  }

  for _, test in ipairs(tests) do
    local line = test.line - 1
    positions[#positions + 1] = {
      id = path .. "::" .. munit.selector(test),
      line = test.line,
      name = test.name,
      path = test.path,
      range = { line, 0, line, 0 },
      suite = test.suite,
      type = "test",
    }
  end

  return positions
end

---@param report_paths string[]
---@return table<string, table>
function M.result_map(report_paths)
  local results = {}
  for _, report_path in ipairs(report_paths) do
    for _, result in ipairs(surefire.parse_file(report_path)) do
      local path = munit_path_for_result(report_path, result)
      local id = path and result_id(path, result) or selector_id(result)
      results[id] = {
        errors = result.message and { { message = result.message } } or nil,
        status = result.status,
      }
    end
  end
  return results
end

---@return table
function M.adapter()
  return {
    name = "mule-munit",
    is_test_file = is_munit_file,
    build_spec = function(args)
      local data = args and args.tree and args.tree:data() or nil
      if data and data.path and data.name then
        return build_spec_for_test(data)
      end

      local path = args and args.file or vim.api.nvim_buf_get_name(0)
      local tests = munit.discover_file(path)
      return tests[1] and build_spec_for_test(tests[1]) or nil
    end,
    discover_positions = function(path)
      local positions = munit_positions(path)
      if positions == nil then
        return nil
      end

      return require("neotest.lib.positions").parse_tree(positions, {
        position_id = function(position)
          return position.id
        end,
      })
    end,
    results = function(_, _, tree)
      local data = tree and tree:data() or {}
      local project = data.path and detect.project(data.path) or nil
      if project == nil then
        return {}
      end
      local reports = vim.fn.glob(project.root .. "/target/surefire-reports/TEST-*.xml", false, true)
      return M.result_map(reports)
    end,
  }
end

return M
