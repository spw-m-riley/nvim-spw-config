local f = require("onebeer.plugins.starter.functions")

---@class OneBeerStarterHooks
local M = {}

---Pad starter content so every section block appears centered.
---@param content MiniStarter.Item[][]
---@return MiniStarter.Item[][]
M.Center = function(content)
  -- Coords
  local header_width = f.content_type_width(content, "header")
  local section_width = f.content_type_width(content, "section")
  local item_width = f.content_type_width(content, "item")
  local footer_width = f.content_type_width(content, "footer")
  local max_width = math.max(header_width, section_width, item_width, footer_width)

  for _, line in ipairs(content) do
    if not (#line == 0 or (#line == 1 and line[1].string == "")) then
      local line_str = ""
      local line_types = {}
      for _, unit in ipairs(line) do
        line_str = line_str .. unit.string
        table.insert(line_types, unit.type)
      end
      local line_width = 0
      for _, type in ipairs(line_types) do
        if type == "item" or type == "section" then
          line_width = math.max(item_width, section_width)
        elseif type == "header" then
          line_width = header_width
        elseif type == "footer" then
          line_width = footer_width
        end
      end
      local left_pad = string.rep(" ", (max_width - line_width) * 0.5)

      table.insert(line, 1, { string = left_pad, type = "empty" })
    end
  end
  return content
end

---Normalize certain section headings inside the starter dashboard.
---@param content MiniStarter.Item[][]
---@return MiniStarter.Item[][]
M.SectionRename = function(content)
  for _, line in ipairs(content) do
    for _, unit in ipairs(line) do
      if unit.type == "section" and unit.string:match("^Recent files") then
        unit.string = "Recent Files"
      end
    end
  end
  return content
end

return M
