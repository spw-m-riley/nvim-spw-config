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

---@param lines string[]
---@param start_line integer
---@param tag string
---@return string|nil, integer|nil
local function opening_tag_at(lines, start_line, tag)
  local opening_line = lines[start_line]
  if
    opening_line == nil
    or (opening_line:match("^%s*<" .. tag .. "$") == nil and opening_line:match("^%s*<" .. tag .. "[%s/>]") == nil)
  then
    return nil, nil
  end

  local parts = {}
  for line_number = start_line, #lines do
    local line = lines[line_number]
    local end_column = line:find(">", 1, true)
    parts[#parts + 1] = end_column and line:sub(1, end_column) or line
    if end_column then
      return table.concat(parts, "\n"), line_number
    end
  end

  return nil, nil
end

---@param tag string
---@param name string
---@return string|nil
local function attribute(tag, name)
  return tag:match(name .. "%s*=%s*[\"']([^\"']+)[\"']")
end

---@param index onebeer.mule.Index
---@param tag string|nil
---@param prefix string
---@param path string
---@param line_number integer
local function index_mule_config(index, tag, prefix, path, line_number)
  local name = tag and attribute(tag, "name") or nil
  if name == nil then
    return
  end
  add_entry(index.configs, prefix .. ":" .. name, path, line_number)
  if prefix ~= "apikit" then
    return
  end
  local api = attribute(tag, "api")
  if api then
    index.apikit_configs[#index.apikit_configs + 1] = {
      name = name,
      api = api,
      path = path,
      line = line_number,
    }
  end
end

---@param index onebeer.mule.Index
---@param lines string[]
---@param path string
---@param line_number integer
---@return integer
local function index_mule_line(index, lines, path, line_number)
  local tag, end_line = opening_tag_at(lines, line_number, "flow")
  if tag then
    local name = attribute(tag, "name")
    if name then
      add_entry(index.flows, name, path, line_number)
    end
    return end_line + 1
  end

  tag, end_line = opening_tag_at(lines, line_number, "sub%-flow")
  if tag then
    local name = attribute(tag, "name")
    if name then
      add_entry(index.subflows, name, path, line_number)
    end
    return end_line + 1
  end

  local prefix = lines[line_number]:match("^%s*<([%w_-]+):config[%s/>]")
    or lines[line_number]:match("^%s*<([%w_-]+):config$")
  if not prefix then
    return line_number + 1
  end

  tag, end_line = opening_tag_at(lines, line_number, prefix .. ":config")
  index_mule_config(index, tag, prefix, path, line_number)
  return end_line and end_line + 1 or line_number + 1
end

---@param index onebeer.mule.Index
---@param path string
local function index_mule_xml(index, path)
  local lines = read_lines(path)
  local line_number = 1
  while line_number <= #lines do
    line_number = index_mule_line(index, lines, path, line_number)
  end
end

---@param path string
---@param lines string[]
---@param target_line integer
---@param line_number integer
---@return onebeer.mule.IndexEntry|nil
---@return integer
local function flow_at_line(path, lines, target_line, line_number)
  local tag, end_line = opening_tag_at(lines, line_number, "flow")
  if tag == nil then
    return nil, line_number + 1
  end
  if target_line > end_line then
    return nil, end_line + 1
  end
  local name = attribute(tag, "name")
  if name == nil then
    return nil, end_line + 1
  end
  return { name = name, path = path, line = line_number }, end_line + 1
end

---@param path string
---@param line integer
---@return onebeer.mule.IndexEntry|nil
function M.flow_at(path, line)
  local lines = read_lines(path)
  local line_number = 1
  while line_number <= line do
    local flow, next_line = flow_at_line(path, lines, line, line_number)
    if flow then
      return flow
    end
    line_number = next_line
  end
  return nil
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
