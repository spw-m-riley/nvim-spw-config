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

---@param node TSNode
---@param buf integer
---@param win integer
---@return onebeer.jump.Target
local function node_target(node, buf, win)
  local start_row, start_col, end_row, end_col = node:range()
  return {
    buf = buf,
    win = win,
    row = start_row + 1,
    col = start_col,
    end_row = end_row + 1,
    end_col = end_col,
    node = node,
  }
end

---@param win integer
---@param buf integer
---@param first integer
---@param last integer
---@return onebeer.jump.Target[]
local function window_treesitter_targets(win, buf, first, last)
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or parser == nil then
    return {}
  end

  local items = {}
  local seen = {}

  local function visit(node)
    local start_row, start_col, end_row, end_col = node:range()
    if end_row < first - 1 or start_row > last - 1 then
      return
    end

    if node:named() and node:named_child_count() == 0 and start_row >= first - 1 and start_row <= last - 1 then
      local key = table.concat({ start_row, start_col, end_row, end_col }, ":")
      if not seen[key] then
        seen[key] = true
        items[#items + 1] = node_target(node, buf, win)
      end
    end

    for child in node:iter_children() do
      visit(child)
    end
  end

  for _, tree in ipairs(parser:parse()) do
    visit(tree:root())
  end
  return items
end

---@param opts? { windows?: integer[] }
---@return onebeer.jump.Target[]
function M.treesitter(opts)
  local items = {}
  for _, win in ipairs(normal_windows(opts and opts.windows)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local first, last = visible_rows(win)
    vim.list_extend(items, window_treesitter_targets(win, buf, first, last))
  end
  return items
end

---@param match string
---@param opts? { windows?: integer[] }
---@return onebeer.jump.Target[]
function M.treesitter_search(match, opts)
  local items = {}
  local seen = {}

  for _, target in ipairs(M.characters(match, opts)) do
    local ok, parser = pcall(vim.treesitter.get_parser, target.buf)
    if ok and parser then
      parser:parse()
      local node = vim.treesitter.get_node({
        bufnr = target.buf,
        pos = { target.row - 1, target.col },
        ignore_injections = false,
      })
      if node then
        while node and not node:named() do
          node = node:parent()
        end
        if node then
          local start_row, start_col, end_row, end_col = node:range()
          local key = table.concat({ target.win, start_row, start_col, end_row, end_col }, ":")
          if not seen[key] then
            seen[key] = true
            items[#items + 1] = node_target(node, target.buf, target.win)
          end
        end
      end
    end
  end
  return items
end

return M
