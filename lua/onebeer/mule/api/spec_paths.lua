---@class onebeer.mule.ApiSpecPaths
local M = {}

---@param project onebeer.mule.Project
---@param api string
---@return string|nil, string|nil
function M.resolve_api(project, api)
  if api:match("^resource::") then
    return nil, "Exchange resource specs are not resolved without a local file"
  end

  local path = project.resources_dir .. "/" .. api
  if vim.uv.fs_stat(path) then
    return path, nil
  end
  return nil, ("API spec is not local: %s"):format(api)
end

---@param project onebeer.mule.Project
---@return string[]
function M.exchange_modules(project)
  local root = project.resources_dir .. "/api/exchange_modules"
  if vim.uv.fs_stat(root) == nil then
    return {}
  end
  local files = vim.fn.glob(root .. "/**/*", false, true)
  table.sort(files)
  return vim.tbl_filter(function(path)
    local stat = vim.uv.fs_stat(path)
    return stat ~= nil and stat.type == "file"
  end, files)
end

return M
