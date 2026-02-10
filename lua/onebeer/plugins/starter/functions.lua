local ministart = require("mini.starter")

---@class OneBeerStarterFunctions
local M = {}

---Calculate display width of starter content matching a section type.
---@param content MiniStarter.Item[][]
---@param section_type MiniStarter.Item["type"]
---@return integer
M.content_type_width = function(content, section_type)
  local coords = ministart.content_coords(content, section_type)
  local width = math.max(unpack(vim.tbl_map(function(c)
    local line = content[c.line][c.unit].string
    return vim.fn.strdisplaywidth(line)
  end, coords)))
  return width
end

return M
