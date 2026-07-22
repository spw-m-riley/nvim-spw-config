local M = {}

---@class onebeer.jump.Target
---@field buf integer
---@field win integer
---@field row integer 1-based buffer row
---@field col integer 0-based byte column
---@field end_row? integer 1-based buffer row
---@field end_col? integer 0-based byte column
---@field node? TSNode
---@field label? string

---@param requested? integer[]
---@return integer[]
local function normal_windows(requested)
  local windows = requested or vim.api.nvim_tabpage_list_wins(0)
  return vim.tbl_filter(function(win)
    if not vim.api.nvim_win_is_valid(win) then
      return false
    end
    local config = vim.api.nvim_win_get_config(win)
    return config.relative == "" and vim.api.nvim_buf_is_valid(vim.api.nvim_win_get_buf(win))
  end, windows)
end

---@param win integer
---@return integer first
---@return integer last
local function visible_rows(win)
  return vim.api.nvim_win_call(win, function()
    return vim.fn.line("w0"), vim.fn.line("w$")
  end)
end

---@param target onebeer.jump.Target
---@return boolean
local function is_cursor(target)
  if target.win ~= vim.api.nvim_get_current_win() then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(target.win)
  return target.row == cursor[1] and target.col == cursor[2]
end

---@param match string
---@param opts? { windows?: integer[] }
---@return onebeer.jump.Target[]
function M.characters(match, opts)
  if match == "" then
    return {}
  end

  local targets = {}
  for _, win in ipairs(normal_windows(opts and opts.windows)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local first, last = visible_rows(win)
    local lines = vim.api.nvim_buf_get_lines(buf, first - 1, last, false)
    for offset, line in ipairs(lines) do
      local start = 1
      while true do
        local found = line:find(match, start, true)
        if found == nil then
          break
        end
        local target = { buf = buf, win = win, row = first + offset - 1, col = found - 1 }
        if not is_cursor(target) then
          targets[#targets + 1] = target
        end
        start = found + math.max(1, #match)
      end
    end
  end
  return targets
end

---@param pattern string
---@param opts? { windows?: integer[] }
---@return onebeer.jump.Target[]
function M.search(pattern, opts)
  if pattern == "" then
    return {}
  end

  local ok, regex = pcall(vim.regex, pattern)
  if not ok then
    return {}
  end

  local targets = {}
  for _, win in ipairs(normal_windows(opts and opts.windows)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local first, last = visible_rows(win)
    local lines = vim.api.nvim_buf_get_lines(buf, first - 1, last, false)
    for offset, line in ipairs(lines) do
      local byte_offset = 0
      while byte_offset <= #line do
        local start_col, end_col = regex:match_str(line:sub(byte_offset + 1))
        if start_col == nil then
          break
        end
        local col = byte_offset + start_col
        local target = {
          buf = buf,
          win = win,
          row = first + offset - 1,
          col = col,
          end_row = first + offset - 1,
          end_col = byte_offset + end_col,
        }
        targets[#targets + 1] = target
        byte_offset = byte_offset + math.max(end_col, start_col + 1)
      end
    end
  end
  return targets
end

return M
