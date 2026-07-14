---@class onebeer.mule.Catalog
local M = {}

local detect = require("onebeer.mule.detect")

---@class onebeer.mule.CatalogMapping
---@field uri string
---@field path string

---@param text string
---@return string
local function xml_escape(text)
  return text:gsub("&", "&amp;"):gsub('"', "&quot;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

---@param project onebeer.mule.Project
---@return string
function M.default_path(project)
  return project.root .. "/.onebeer/mule-catalog.xml"
end

---@param path string
---@return string|nil
local function read_target_namespace(path)
  local ok, lines = pcall(vim.fn.readfile, path, "", 200)
  if not ok then
    return nil
  end

  local text = table.concat(lines, "\n")
  return text:match('targetNamespace%s*=%s*"(.-)"') or text:match("targetNamespace%s*=%s*'(.-)'")
end

---@param project onebeer.mule.Project
---@return onebeer.mule.CatalogMapping[]
function M.discover(project)
  local files = {}
  local patterns = {
    project.root .. "/src/main/resources/**/*.xsd",
    project.root .. "/exchange_modules/**/*.xsd",
  }

  for _, pattern in ipairs(patterns) do
    local matches = vim.fn.glob(pattern, false, true)
    for _, path in ipairs(matches) do
      local stat = vim.uv.fs_stat(path)
      if stat ~= nil and stat.type == "file" then
        files[#files + 1] = path
      end
    end
  end

  table.sort(files)
  local mappings = {}
  local seen_namespaces = {}
  for _, path in ipairs(files) do
    local uri = read_target_namespace(path)
    if uri ~= nil and uri ~= "" and not seen_namespaces[uri] then
      seen_namespaces[uri] = true
      mappings[#mappings + 1] = {
        uri = uri,
        path = path,
      }
    end
  end
  return mappings
end

---@param output string
---@param mappings onebeer.mule.CatalogMapping[]
---@return boolean, string|nil
function M.write(output, mappings)
  local parent = vim.fn.fnamemodify(output, ":h")
  local mkdir_ok, mkdir_result = pcall(vim.fn.mkdir, parent, "p")
  if not mkdir_ok or mkdir_result == 0 or vim.fn.isdirectory(parent) ~= 1 then
    return false, ("Failed to create catalog directory for %s"):format(output)
  end

  local lines = {
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog">',
  }
  for _, mapping in ipairs(mappings) do
    lines[#lines + 1] = ('  <uri name="%s" uri="%s" />'):format(
      xml_escape(mapping.uri),
      xml_escape(vim.fs.normalize(mapping.path))
    )
  end
  lines[#lines + 1] = "</catalog>"

  local write_ok, write_result = pcall(vim.fn.writefile, lines, output)
  if not write_ok or write_result ~= 0 then
    return false, ("Failed to write Mule XML catalog to %s"):format(output)
  end
  return true, nil
end

---@param startpath? string
---@param mappings? onebeer.mule.CatalogMapping[]
---@param output? string
---@param opts? { allow_empty?: boolean }
---@return string|nil, string|nil
function M.generate(startpath, mappings, output, opts)
  local project = detect.project(startpath)
  if project == nil then
    return nil, "No Mule project detected"
  end

  local resolved_mappings = mappings or M.discover(project)
  local allow_empty = opts ~= nil and opts.allow_empty == true
  if #resolved_mappings == 0 and not allow_empty then
    return nil, "No Mule XML schema mappings found under src/main/resources or exchange_modules"
  end

  local catalog_path = output or M.default_path(project)
  local written, err = M.write(catalog_path, resolved_mappings)
  if not written then
    return nil, err
  end
  return catalog_path, nil
end

return M
