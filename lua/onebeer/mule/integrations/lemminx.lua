---@class onebeer.mule.LemMinXIntegration
local M = {}

local catalog = require("onebeer.mule.catalog")
local detect = require("onebeer.mule.detect")

---@param root string
---@return string
local function catalog_path_for_root(root)
  return catalog.default_path({ root = vim.fs.normalize(root) })
end

---@param root string|nil
---@return table
function M.settings_for_root(root)
  if type(root) ~= "string" or root == "" or not detect.is_mule_root(root) then
    return {}
  end

  local catalog_path = catalog_path_for_root(root)
  if vim.uv.fs_stat(catalog_path) == nil then
    return {}
  end

  return {
    xml = {
      catalogs = { catalog_path },
    },
  }
end

---@param path string
---@return table
function M.settings_for_path(path)
  if not detect.is_mule_xml(path) then
    return {}
  end

  local project = detect.project(path)
  if project == nil then
    return {}
  end

  return M.settings_for_root(project.root)
end

---@param bufnr integer
---@param on_dir fun(root_dir?: string)
function M.root_dir(bufnr, on_dir)
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    return
  end

  local project = detect.project(path)
  if project ~= nil and detect.is_mule_xml(path) then
    on_dir(project.root)
    return
  end

  local parent = vim.fs.dirname(path)
  if project ~= nil then
    on_dir(parent)
    return
  end

  local git_root = vim.fs.root(parent, { ".git" })
  on_dir(git_root or parent)
end

---@param client vim.lsp.Client
---@param path string
---@return boolean
function M.apply(client, path)
  local settings = M.settings_for_path(path)
  if next(settings) == nil then
    return false
  end

  client.settings = vim.tbl_deep_extend("force", client.settings or {}, settings)
  if not client:notify("workspace/didChangeConfiguration", { settings = nil }) then
    error("LemMinX client rejected workspace/didChangeConfiguration")
  end
  return true
end

---@param path string
---@return integer
function M.refresh(path)
  local project = detect.is_mule_xml(path) and detect.project(path) or nil
  if project == nil then
    return 0
  end

  local root = vim.fs.normalize(project.root)
  local refreshed = 0
  for _, client in ipairs(vim.lsp.get_clients({ name = "lemminx" })) do
    local client_root = client.config and client.config.root_dir or nil
    if type(client_root) == "string" and vim.fs.normalize(client_root) == root and M.apply(client, path) then
      refreshed = refreshed + 1
    end
  end

  return refreshed
end

return M
