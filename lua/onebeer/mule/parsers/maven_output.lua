---@class onebeer.mule.MavenOutputParser
local M = {}

---@param text string
---@return string[]
local function lines(text)
  return vim.split(text or "", "\n", { plain = true, trimempty = true })
end

---@param line string
---@return table|nil
local function parse_location(line)
  local file, lnum, col, message = line:match("^%[ERROR%]%s+(.+):%[(%d+),(%d+)%]%s+(.+)$")
  if file then
    return {
      filename = file,
      lnum = tonumber(lnum),
      col = tonumber(col),
      text = message,
      type = "E",
    }
  end

  file, lnum, message = line:match("^%[ERROR%]%s+(.+):(%d+)%s+(.+)$")
  if file then
    return {
      filename = file,
      lnum = tonumber(lnum),
      text = message,
      type = "E",
    }
  end

  return nil
end

---@param result vim.SystemCompleted
---@return table
local function fallback_item(result)
  local message = vim.trim((result.stderr ~= "" and result.stderr) or result.stdout or ("exit code " .. result.code))
  return {
    text = message ~= "" and message or "Maven command failed",
    type = "E",
  }
end

---@param result vim.SystemCompleted
---@return table[]
function M.quickfix_items(result)
  local items = {}
  for _, line in ipairs(lines((result.stderr or "") .. "\n" .. (result.stdout or ""))) do
    local item = parse_location(line)
    if item then
      items[#items + 1] = item
    end
  end
  if #items > 0 then
    return items
  end
  return { fallback_item(result) }
end

return M
