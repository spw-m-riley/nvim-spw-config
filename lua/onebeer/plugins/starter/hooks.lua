local f = require("onebeer.plugins.starter.functions")

---@class OneBeerStarterHooks
local M = {}

---@param line MiniStarter.Item[]
---@param widths table<string, integer>
---@return string
local function centered_line_padding(line, widths)
  local line_types = {}
  for _, unit in ipairs(line) do
    line_types[#line_types + 1] = unit.type
  end
  local line_width = 0
  for _, type in ipairs(line_types) do
    if type == "item" or type == "section" then
      line_width = math.max(widths.item, widths.section)
    elseif type == "header" then
      line_width = widths.header
    elseif type == "footer" then
      line_width = widths.footer
    end
  end
  return string.rep(" ", (widths.max - line_width) * 0.5)
end

---@param line MiniStarter.Item[]
---@return boolean
local function is_empty_line(line)
  return #line == 0 or (#line == 1 and line[1].string == "")
end

---Pad starter content so every section block appears centered.
---@param content MiniStarter.Item[][]
---@return MiniStarter.Item[][]
M.Center = function(content)
  local widths = {
    header = f.content_type_width(content, "header"),
    section = f.content_type_width(content, "section"),
    item = f.content_type_width(content, "item"),
    footer = f.content_type_width(content, "footer"),
  }
  widths.max = math.max(widths.header, widths.section, widths.item, widths.footer)

  for _, line in ipairs(content) do
    if not is_empty_line(line) then
      table.insert(line, 1, { string = centered_line_padding(line, widths), type = "empty" })
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
