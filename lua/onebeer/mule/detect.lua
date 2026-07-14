---@class onebeer.mule.Project
---@field root string
---@field pom string
---@field mule_artifact string
---@field mule_dir string
---@field resources_dir string
---@field munit_dir string

local M = {}

---@param path string
---@return boolean
local function exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

---@param path string
---@return boolean
local function is_dir(path)
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "directory"
end

---@param path string
---@return string
local function normalize(path)
  return vim.fs.normalize(path)
end

---@param path string
---@return string
local function parent_if_file(path)
  local normalized = normalize(path)
  if is_dir(normalized) then
    return normalized
  end
  return vim.fn.fnamemodify(normalized, ":h")
end

---@param root string
---@return boolean
function M.is_mule_root(root)
  local normalized = normalize(root)
  return exists(normalized .. "/pom.xml")
    and exists(normalized .. "/mule-artifact.json")
    and is_dir(normalized .. "/src/main/mule")
end

---@param startpath? string
---@return string|nil
function M.find_root(startpath)
  local start = parent_if_file(startpath or vim.api.nvim_buf_get_name(0))
  local found = vim.fs.find(function(name, path)
    if name ~= "mule-artifact.json" then
      return false
    end
    return M.is_mule_root(path)
  end, {
    upward = true,
    path = start,
    type = "file",
  })[1]

  return found and vim.fn.fnamemodify(found, ":h") or nil
end

---@param startpath? string
---@return onebeer.mule.Project|nil
function M.project(startpath)
  local root = M.find_root(startpath)
  if root == nil then
    return nil
  end

  return {
    root = root,
    pom = root .. "/pom.xml",
    mule_artifact = root .. "/mule-artifact.json",
    mule_dir = root .. "/src/main/mule",
    resources_dir = root .. "/src/main/resources",
    munit_dir = root .. "/src/test/munit",
  }
end

---@param path string
---@param prefix string
---@return boolean
local function has_prefix(path, prefix)
  local normalized_path = normalize(path)
  local normalized_prefix = normalize(prefix)
  return normalized_path == normalized_prefix or vim.startswith(normalized_path, normalized_prefix .. "/")
end

---@param bufnr_or_path? integer|string
---@return boolean
function M.is_mule_xml(bufnr_or_path)
  local path
  if type(bufnr_or_path) == "number" then
    path = vim.api.nvim_buf_get_name(bufnr_or_path)
  elseif type(bufnr_or_path) == "string" then
    path = bufnr_or_path
  else
    path = vim.api.nvim_buf_get_name(0)
  end

  if path == nil or path == "" or vim.fn.fnamemodify(path, ":e") ~= "xml" then
    return false
  end

  local project = M.project(path)
  if project == nil then
    return false
  end

  return has_prefix(path, project.mule_dir) or has_prefix(path, project.munit_dir)
end

return M
