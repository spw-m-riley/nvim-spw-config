---@class onebeer.mule.DataWeaveParser
local M = {}

---@param result vim.SystemCompleted
---@param path? string
---@return table[]
function M.quickfix_items(result, path)
  local text = (result.stderr or "") .. "\n" .. (result.stdout or "")
  local line, col, message = text:match("line%s+(%d+),%s+column%s+(%d+):%s*([^\n]+)")
  if line then
    return {
      {
        col = tonumber(col),
        filename = path,
        lnum = tonumber(line),
        text = message,
        type = "E",
      },
    }
  end

  return {
    {
      filename = path,
      text = vim.trim(text) ~= "" and vim.trim(text) or "DataWeave command failed",
      type = "E",
    },
  }
end

return M
