---@class onebeer.mule.LemMinXIntegration
local M = {}

local catalog = require("onebeer.mule.catalog")
local detect = require("onebeer.mule.detect")

---@param bufnr? integer
---@return table|nil
function M.settings(bufnr)
  local path = bufnr and vim.api.nvim_buf_get_name(bufnr) or vim.api.nvim_buf_get_name(0)
  if not detect.is_mule_xml(path) then
    return nil
  end

  local project = detect.project(path)
  if project == nil then
    return nil
  end

  local catalog_path = catalog.default_path(project)
  if vim.uv.fs_stat(catalog_path) == nil then
    return nil
  end

  return {
    settings = {
      xml = {
        catalogs = { catalog_path },
      },
    },
  }
end

return M
