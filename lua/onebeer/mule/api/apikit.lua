---@class onebeer.mule.ApiKit
local M = {}

local detect = require("onebeer.mule.detect")
local indexer = require("onebeer.mule.index")
local spec_paths = require("onebeer.mule.api.spec_paths")

local methods = {
  delete = true,
  get = true,
  head = true,
  options = true,
  patch = true,
  post = true,
  put = true,
}

---@class onebeer.mule.ApiKitRoute
---@field method string
---@field path string
---@field mime string|nil
---@field config string

---@param value string
---@return string
local function unescape_path(value)
  local path = value:gsub("\\", "/")
  return vim.startswith(path, "/") and path or ("/" .. path)
end

---@param name string
---@return onebeer.mule.ApiKitRoute|nil
function M.parse_flow_name(name)
  local parts = vim.split(name, ":", { plain = true })
  if #parts < 3 then
    return nil
  end

  local method = parts[1]
  if not methods[method] then
    return nil
  end

  local config = parts[#parts]
  local mime = #parts > 3 and parts[#parts - 1]:gsub("\\", "/") or nil
  return {
    config = config,
    method = method,
    mime = mime,
    path = unescape_path(parts[2]),
  }
end

---@param xml_path string
---@param line integer
---@return onebeer.mule.IndexEntry|nil
function M.generated_flow_at(xml_path, line)
  if not detect.is_mule_xml(xml_path) then
    return nil
  end

  local flow = indexer.flow_at(xml_path, line)
  if flow == nil or M.parse_flow_name(flow.name) == nil then
    return nil
  end

  return flow
end

---@param spec_path string
---@param route onebeer.mule.ApiKitRoute
---@return integer|nil
local function find_raml_route_line(spec_path, route)
  local ok, lines = pcall(vim.fn.readfile, spec_path)
  if not ok then
    return nil
  end

  local route_line
  local route_indent
  local stack = {}
  for line_number, line in ipairs(lines) do
    local indent = #(line:match("^%s*") or "")
    local path_segment = line:match("^%s*(/[^:]+):%s*$")

    if path_segment then
      if route_line then
        return route_line
      end

      while #stack > 0 and stack[#stack].indent >= indent do
        stack[#stack] = nil
      end

      stack[#stack + 1] = {
        indent = indent,
        path = path_segment,
      }

      local full_path = table.concat(
        vim.tbl_map(function(item)
          return item.path
        end, stack),
        ""
      )

      if full_path == route.path then
        route_line = line_number
        route_indent = indent
      end
    elseif route_line and indent <= route_indent and line:match("%S") then
      return route_line
    elseif route_line and line:match("^%s+" .. route.method .. ":%s*$") then
      return line_number
    end
  end

  return route_line
end

---@param line string
---@return string|nil
local function oas_path_from_line(line)
  return line:match("^%s*[\"']?(/[^\"']-)[\"']?%s*:%s*[{%[]?%s*,?%s*$")
end

---@param line string
---@param method string
---@return boolean
local function is_oas_method_line(line, method)
  return line:match("^%s*[\"']?" .. method .. "[\"']?%s*:%s*[{%[]?%s*,?%s*$") ~= nil
end

---@param spec_path string
---@param route onebeer.mule.ApiKitRoute
---@return integer|nil
local function find_oas_route_line(spec_path, route)
  local ok, lines = pcall(vim.fn.readfile, spec_path)
  if not ok then
    return nil
  end

  local paths_indent
  local route_line
  local route_indent
  for line_number, line in ipairs(lines) do
    local indent = #(line:match("^%s*") or "")

    if paths_indent == nil and line:match("^%s*[\"']?paths[\"']?%s*:%s*{?%s*$") then
      paths_indent = indent
    elseif paths_indent and indent <= paths_indent and line:match("%S") then
      return route_line
    elseif paths_indent then
      local path = oas_path_from_line(line)
      if path and indent > paths_indent then
        if route_line then
          return route_line
        end
        if path == route.path then
          route_line = line_number
          route_indent = indent
        end
      elseif route_line and indent <= route_indent and line:match("%S") then
        return route_line
      elseif route_line and is_oas_method_line(line, route.method) then
        return line_number
      end
    end
  end

  return route_line
end

---@param spec_path string
---@param route onebeer.mule.ApiKitRoute
---@return integer|nil, string|nil
local function find_route_line(spec_path, route)
  local lower = spec_path:lower()
  if lower:match("%.raml$") then
    return find_raml_route_line(spec_path, route), nil
  end
  if lower:match("%.ya?ml$") or lower:match("%.json$") then
    return find_oas_route_line(spec_path, route), nil
  end
  return nil, ("API spec type is not supported: %s"):format(spec_path)
end

---@param method string
---@param path string
---@param spec_path string
---@return string
local function route_not_found(method, path, spec_path)
  return ("APIKit route not found in %s: %s %s"):format(spec_path, method:upper(), path)
end

---@param xml_path string
---@param flow_name string
---@return table|nil, string|nil
function M.route_for_flow(xml_path, flow_name)
  if not detect.is_mule_xml(xml_path) then
    return nil, "Not a Mule XML buffer"
  end

  local route = M.parse_flow_name(flow_name)
  if route == nil then
    return nil, "Not an APIKit generated flow name"
  end

  local project = detect.project(xml_path)
  local index = project and indexer.build(xml_path) or nil
  if project == nil or index == nil then
    return nil, "No Mule project detected"
  end

  for _, config in ipairs(index.apikit_configs) do
    if config.name == route.config then
      local spec_path, spec_err = spec_paths.resolve_api(project, config.api)
      if spec_path == nil then
        return nil, spec_err or "API spec is not local"
      end

      local line, route_err = find_route_line(spec_path, route)
      if route_err then
        return nil, route_err
      end
      if line == nil then
        return nil, route_not_found(route.method, route.path, spec_path)
      end

      return {
        line = line,
        method = route.method,
        path = route.path,
        spec_path = spec_path,
      },
        nil
    end
  end

  return nil, ("APIKit config not found: %s"):format(route.config)
end

return M
