---@alias LuaSnipNode any
---@alias LuaSnipNodeList LuaSnipNode[]

---@param buf integer
---@param path string
---@param text_node function
---@param snippets LuaSnipNodeList
local function append_buffer_functions(buf, path, text_node, snippets)
  if vim.api.nvim_buf_get_name(buf) ~= path then
    return
  end
  local query_api = require("vim.treesitter.query")
  local root = vim.treesitter.get_parser(buf, "typescript", {}):parse()[1]:root()
  local query = vim.treesitter.query(
    "typescript",
    [[
      (method_definition
        name: (property_identifier) @name
      )
    ]]
  )
  for _, cap in query:iter_matches(root, buf) do
    local method_name = query_api.get_node_text(cap[1], buf)
    if method_name ~= "constructor" then
      table.insert(snippets, text_node({ 'describe("#' .. method_name .. '", () => {', "", "});", "" }))
    end
  end
end

---@return LuaSnipNode
local get_functions = function()
  local ls = require("luasnip")
  local import_file_path = string.gsub(vim.api.nvim_buf_get_name(0), ".spec*.", "")
  local snippets = {}
  for _, buf in next, vim.api.nvim_list_bufs() do
    append_buffer_functions(buf, import_file_path, ls.text_node, snippets)
  end
  return ls.snippet_node(nil, snippets)
end

return get_functions
