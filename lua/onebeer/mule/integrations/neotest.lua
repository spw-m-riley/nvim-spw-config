---@class onebeer.mule.NeotestIntegration
local M = {}

local config = require("onebeer.mule.config")
local dap = require("onebeer.mule.integrations.dap")
local detect = require("onebeer.mule.detect")
local munit = require("onebeer.mule.jobs.munit")
local surefire = require("onebeer.mule.parsers.surefire")

---@param path string
---@return boolean
function M.is_munit_file(path)
  return path:match("/src/test/munit/.+%.xml$") ~= nil and detect.project(path) ~= nil
end

---@param path string
---@param selector string
---@return table|nil
local function build_spec(path, selector)
  local project = detect.project(path)
  if project == nil then
    return nil
  end

  local command = config.command("maven", {
    "clean",
    "test",
    "-Dmunit.test=" .. selector,
  })
  if command == nil then
    return nil
  end

  return {
    command = command,
    cwd = project.root,
  }
end

---@param data table
---@return table|nil
local function build_spec_for_position(data)
  if data.type == "file" and data.path then
    return build_spec(data.path, munit.suite_selector(data.path))
  end
  if data.type == "test" and data.path and data.suite and data.name then
    return build_spec(data.path, ("%s#%s"):format(data.suite, data.name))
  end
  return nil
end

---@param path string
---@param selector string
---@return string
local function result_id(path, selector)
  return ("%s::%s"):format(path, selector)
end

---@param project onebeer.mule.Project
---@return table<string, string>
local function suite_paths(project)
  local paths = {}
  for _, test in ipairs(munit.discover(project.root)) do
    paths[test.suite] = test.path
  end
  return paths
end

---@param result onebeer.mule.TestResult
---@return string
local function selector_id(result)
  return ("%s#%s"):format(result.classname, result.name)
end

---@param path string
---@return table[]|nil
local function munit_positions(path)
  if not M.is_munit_file(path) then
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

---@param report_path string
---@param projects table<string, table<string, string>>
---@return table[]
---@return table<string, integer>
local function report_entries(report_path, projects)
  local project = detect.project(report_path)
  local suite_path_map
  if project then
    suite_path_map = projects[project.root]
    if suite_path_map == nil then
      suite_path_map = suite_paths(project)
      projects[project.root] = suite_path_map
    end
  end

  local entries = {}
  local fallback_counts = {}
  for _, result in ipairs(surefire.parse_file(report_path)) do
    local selector = selector_id(result)
    local path = suite_path_map and suite_path_map[result.classname] or nil
    entries[#entries + 1] = { path = path, result = result, selector = selector }
    if path == nil then
      fallback_counts[selector] = (fallback_counts[selector] or 0) + 1
    end
  end
  return entries, fallback_counts
end

---@param entry table
---@param fallback_counts table<string, integer>
---@param results table<string, table>
---@param diagnostics string[]
local function add_result_entry(entry, fallback_counts, results, diagnostics)
  local id
  if entry.path then
    id = result_id(entry.path, entry.selector)
  elseif fallback_counts[entry.selector] == 1 then
    id = entry.selector
    diagnostics[#diagnostics + 1] = ("Unmapped MUnit Surefire result: %s"):format(entry.selector)
  else
    diagnostics[#diagnostics + 1] = ("Ambiguous MUnit Surefire result omitted: %s"):format(entry.selector)
  end
  if id then
    results[id] = {
      errors = entry.result.message and { { message = entry.result.message } } or nil,
      status = entry.result.status,
    }
  end
end

---@param report_paths string[]
---@return table<string, table>
---@return string[]
function M.result_map(report_paths)
  local results = {}
  local diagnostics = {}
  local projects = {}
  local entries = {}
  local fallback_counts = {}

  for _, report_path in ipairs(report_paths) do
    local report_entries_for_path, report_fallback_counts = report_entries(report_path, projects)
    vim.list_extend(entries, report_entries_for_path)
    for selector, count in pairs(report_fallback_counts) do
      fallback_counts[selector] = (fallback_counts[selector] or 0) + count
    end
  end
  for _, entry in ipairs(entries) do
    add_result_entry(entry, fallback_counts, results, diagnostics)
  end
  return results, diagnostics
end

---@return table
function M.adapter()
  return {
    name = "mule-munit",
    is_test_file = M.is_munit_file,
    build_spec = function(args)
      local data = args and args.tree and args.tree:data() or nil
      if data then
        if args.strategy == "dap" then
          local can_debug = dap.guard(data.path)
          if not can_debug then
            return nil
          end
        end
        return build_spec_for_position(data)
      end

      local path = args and args.file or vim.api.nvim_buf_get_name(0)
      if args and args.strategy == "dap" then
        local can_debug = dap.guard(path)
        if not can_debug then
          return nil
        end
      end
      if not M.is_munit_file(path) then
        return nil
      end
      return build_spec(path, munit.suite_selector(path))
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
