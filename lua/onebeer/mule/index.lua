---@class onebeer.mule.IndexEntry
---@field name string
---@field path string
---@field line integer

---@class onebeer.mule.Index
---@field root string
---@field files table<string, string[]>
---@field flows onebeer.mule.IndexEntry[]
---@field subflows onebeer.mule.IndexEntry[]
---@field configs onebeer.mule.IndexEntry[]
---@field dataweave_resources onebeer.mule.IndexEntry[]
---@field apikit_configs table[]
---@field munit_suites table[]

local detect = require("onebeer.mule.detect")

local M = {}

---@param pattern string
---@return string[]
local function glob(pattern)
  local files = vim.fn.glob(pattern, false, true)
  table.sort(files)
  return files
end

---@param path string
---@return string[]
local function read_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and lines or {}
end

---@param entries onebeer.mule.IndexEntry[]
---@param name string
---@param path string
---@param line integer
local function add_entry(entries, name, path, line)
  entries[#entries + 1] = {
    name = name,
    path = path,
    line = line,
  }
end

---@param index onebeer.mule.Index
---@param path string
local function index_mule_xml(index, path)
  for line_number, line in ipairs(read_lines(path)) do
    for flow in line:gmatch("<flow%s+[^>]-name=[\"']([^\"']+)") do
      add_entry(index.flows, flow, path, line_number)
    end
    for subflow in line:gmatch("<sub%-flow%s+[^>]-name=[\"']([^\"']+)") do
      add_entry(index.subflows, subflow, path, line_number)
    end
    for prefix, name in line:gmatch("<([%w_-]+):config%s+[^>]-name=[\"']([^\"']+)") do
      add_entry(index.configs, prefix .. ":" .. name, path, line_number)
    end
    for name, api in line:gmatch("<apikit:config%s+[^>]-name=[\"']([^\"']+)[\"'][^>]-api=[\"']([^\"']+)") do
      index.apikit_configs[#index.apikit_configs + 1] = {
        name = name,
        api = api,
        path = path,
        line = line_number,
      }
    end
  end
end

---@param index onebeer.mule.Index
---@param path string
local function index_munit_xml(index, path)
  local suite = {
    path = path,
    tests = {},
  }
  for line_number, line in ipairs(read_lines(path)) do
    for name in line:gmatch("<munit:test%s+[^>]-name=[\"']([^\"']+)") do
      suite.tests[#suite.tests + 1] = {
        name = name,
        path = path,
        line = line_number,
      }
    end
  end
  index.munit_suites[#index.munit_suites + 1] = suite
end

---@param startpath? string
---@return onebeer.mule.Index|nil
function M.build(startpath)
  local project = detect.project(startpath)
  if project == nil then
    return nil
  end

  ---@type onebeer.mule.Index
  local index = {
    root = project.root,
    files = {
      dataweave = glob(project.resources_dir .. "/**/*.dwl"),
      mule = glob(project.mule_dir .. "/**/*.xml"),
      munit = glob(project.munit_dir .. "/**/*.xml"),
    },
    apikit_configs = {},
    configs = {},
    dataweave_resources = {},
    flows = {},
    munit_suites = {},
    subflows = {},
  }

  for _, path in ipairs(index.files.mule) do
    index_mule_xml(index, path)
  end
  for _, path in ipairs(index.files.munit) do
    index_munit_xml(index, path)
  end
  for _, path in ipairs(index.files.dataweave) do
    add_entry(index.dataweave_resources, vim.fn.fnamemodify(path, ":."), path, 1)
  end

  return index
end

return M
