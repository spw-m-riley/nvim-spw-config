---@alias LuaSnipNode any
---@alias LuaSnipNodeList LuaSnipNode[]

---@return LuaSnipNode
local get_functions = function()
  local ls = require("luasnip")
  local t = ls.text_node
  local sn = ls.snippet_node

  local get_buffer_path = vim.api.nvim_buf_get_name(0)
  local import_file_path = string.gsub(get_buffer_path, ".spec*.", "")
  ---@type integer[]
  local buff_list = vim.api.nvim_list_bufs()
  ---@type LuaSnipNodeList
  local sn_tbl = {}
  for _, val in next, buff_list do
    local iter_buf_name = vim.api.nvim_buf_get_name(val)
    if not (iter_buf_name == "" or iter_buf_name == nil) and (iter_buf_name == import_file_path)
    then
      local q = require("vim.treesitter.query")
      local lang_tree = vim.treesitter.get_parser(val, "typescript", {})
      local syntax_tree = lang_tree:parse()
      local root = syntax_tree[1]:root()

      local query = vim.treesitter.query(
        "typescript",
        [[
          (method_definition
            name: (property_identifier) @name
          )
        ]]
      )

      for _, cap in query:iter_matches(root, val) do
        ---@type string
        local method_name = q.get_node_text(cap[1], val)
        if not (method_name == "constructor") then
          table.insert(sn_tbl, t({ 'describe("#' .. method_name .. '", () => {', "", "});", "" }))
        end
      end
    end
  end
  return sn(nil, sn_tbl)
end

return get_functions
