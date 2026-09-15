---@class onebeer.pack_modules
local M = {}

---@param path string
---@param prefix string
---@return string[]
local function scandir(path, prefix)
  ---@type string[]
  local modules = {}

  for name, kind in vim.fs.dir(path) do
    if kind == "file" and name:sub(-4) == ".lua" then
      local module = table.concat({ prefix, name:sub(1, -5) }, ".")
      table.insert(modules, module)
    end
  end

  table.sort(modules)
  return modules
end

---@return string[]
function M.list()
  local config = vim.fn.stdpath("config")
  local modules = scandir(config .. "/lua/onebeer/plugins", "onebeer.plugins")

  vim.list_extend(modules, scandir(config .. "/lua/onebeer/plugins/lsp", "onebeer.plugins.lsp"))
  table.insert(modules, "onebeer.plugins.luasnip.init")

  return modules
end

return M
