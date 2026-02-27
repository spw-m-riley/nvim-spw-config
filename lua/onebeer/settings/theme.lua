---Fetch a highlight group's foreground colour as hex.
---@param name string
---@return string
local function getHighlightHex(name)
  local ok, colour = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if not ok or not colour or not colour.fg then
    return "#000000"
  end
  return "#" .. string.format("%06x", colour.fg)
end

---@class OneBeerThemePalettes
---@field base table<string, string>
---@field vi_mode table<string, string>

---@class OneBeerTheme
---@field colours OneBeerThemePalettes
local M = {
  ---@type OneBeerThemePalettes
  colours = {},
}

M.colours.base = {
  blue = getHighlightHex("Function"),
  cyan = getHighlightHex("Title"),
  magenta = getHighlightHex("SignColumn"),
  orange = getHighlightHex("WarningMsg"),
  red = getHighlightHex("ErrorMsg"),
  purple = getHighlightHex("Todo"),
  text_normal = getHighlightHex("Label"),
  text_with_color = getHighlightHex("NonText"),
  yellow = getHighlightHex("MatchParen"),
  green = getHighlightHex("String"),
  gray = getHighlightHex("Whitespace"),
}

M.colours.vi_mode = {
  NORMAL = M.colours.base.blue,
  OP = M.colours.base.magenta,
  INSERT = M.colours.base.green,
  VISUAL = M.colours.base.purple,
  BLOCK = M.colours.base.purple,
  REPLACE = M.colours.red,
  ["V-REPLACE"] = M.colours.base.red,
  ENTER = M.colours.base.cyan,
  MORE = M.colours.base.cyan,
  SELECT = M.colours.base.orange,
  COMMAND = M.colours.base.gray,
  SHELL = M.colours.base.cyan,
  TERM = M.colours.base.cyan,
  NONE = M.colours.base.yellow,
  LINES = M.colours.base.purple,
}

return M
