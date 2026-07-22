local labels = require("onebeer.jump.labels")
local render = require("onebeer.jump.render")
local targets = require("onebeer.jump.targets")
local utils = require("onebeer.utils")

local M = {}

local search_labels_enabled = true

---@param value string?
---@return boolean
local function is_cancel(value)
  return value == nil
    or value == ""
    or value == "\027"
    or value == vim.keycode("<Esc>")
    or value == vim.keycode("<C-c>")
end

---@return string
local function read_key()
  return vim.fn.getcharstr()
end

---@return string?
local function read_motion()
  local parts = {}
  local key = read_key()
  if is_cancel(key) then
    return nil
  end

  while key:match("^%d$") do
    parts[#parts + 1] = key
    key = read_key()
    if is_cancel(key) then
      return nil
    end
  end

  parts[#parts + 1] = key
  local prefixes = { a = true, f = true, F = true, g = true, i = true, t = true, T = true, ["["] = true, ["]"] = true }
  if prefixes[key] then
    local suffix = read_key()
    if is_cancel(suffix) then
      return nil
    end
    parts[#parts + 1] = suffix
  end
  return table.concat(parts)
end

---@param items onebeer.jump.Target[]
local function assign_labels(items)
  local generated = labels.generate(#items)
  for index, target in ipairs(items) do
    target.label = target.label or generated[index]
  end
end

---@param items onebeer.jump.Target[]
---@param input? fun(): string?
---@return onebeer.jump.Target?
function M.select(items, input)
  if #items == 0 then
    return nil
  end

  assign_labels(items)
  input = input or read_key

  local function choose()
    local candidates = items
    local prefix = ""
    render.show(candidates)
    vim.cmd.redraw()

    while #candidates > 0 do
      local key = input()
      if is_cancel(key) then
        return nil
      end

      prefix = prefix .. key
      candidates = vim.tbl_filter(function(target)
        return vim.startswith(target.label, prefix)
      end, candidates)

      if #candidates == 1 and candidates[1].label == prefix then
        return candidates[1]
      end
      render.show(candidates)
      vim.cmd.redraw()
    end
    return nil
  end

  local ok, selected = xpcall(choose, debug.traceback)
  render.clear()
  vim.cmd.redraw()
  if not ok then
    error(selected)
  end
  return selected
end

---@param target onebeer.jump.Target
function M.move(target)
  assert(vim.api.nvim_win_is_valid(target.win), "jump target window is no longer valid")
  assert(vim.api.nvim_buf_is_valid(target.buf), "jump target buffer is no longer valid")
  vim.api.nvim_set_current_win(target.win)
  if vim.api.nvim_win_get_buf(target.win) ~= target.buf then
    vim.api.nvim_win_set_buf(target.win, target.buf)
  end
  vim.api.nvim_win_set_cursor(target.win, { target.row, target.col })
end

---@param items onebeer.jump.Target[]
---@param input? fun(): string?
---@return onebeer.jump.Target?
local function pick(items, input)
  local target = M.select(items, input)
  if target == nil and #items == 0 then
    vim.notify("No visible jump targets", vim.log.levels.INFO, { title = "OneBeer Jump" })
  end
  return target
end

---@param opts? { char?: string, input?: fun(): string? }
---@return onebeer.jump.Target?
local function character_target(opts)
  opts = opts or {}
  local char = opts.char or read_key()
  if is_cancel(char) then
    return nil
  end
  return pick(targets.characters(char), opts.input)
end

---@param opts? { char?: string, input?: fun(): string? }
---@return onebeer.jump.Target?
function M.jump(opts)
  local target = character_target(opts)
  if target then
    M.move(target)
  end
  return target
end

---@param target onebeer.jump.Target
function M.select_node(target)
  assert(target.end_row and target.end_col, "Treesitter target is missing its end position")
  M.move(target)

  local end_row = target.end_row
  local end_col = target.end_col
  if end_col == 0 and end_row > target.row then
    end_row = end_row - 1
    local line = vim.api.nvim_buf_get_lines(target.buf, end_row - 1, end_row, false)[1] or ""
    end_col = math.max(0, #line - 1)
  else
    end_col = math.max(0, end_col - 1)
  end

  vim.cmd.normal({ "v", bang = true })
  vim.api.nvim_win_set_cursor(target.win, { end_row, end_col })
end

---@param opts? { input?: fun(): string? }
function M.treesitter(opts)
  opts = opts or {}
  local items = type(targets.treesitter) == "function" and targets.treesitter() or {}
  local target = pick(items, opts.input)
  if target then
    M.move(target)
  end
end

---@param opts? { char?: string, input?: fun(): string? }
function M.remote(opts)
  local operator = vim.v.operator
  if operator == "" then
    M.jump(opts)
    return
  end

  local origin = {
    buf = vim.api.nvim_get_current_buf(),
    cursor = vim.api.nvim_win_get_cursor(0),
    view = vim.fn.winsaveview(),
    win = vim.api.nvim_get_current_win(),
  }
  local function restore()
    if not vim.api.nvim_win_is_valid(origin.win) or not vim.api.nvim_buf_is_valid(origin.buf) then
      return
    end
    vim.api.nvim_set_current_win(origin.win)
    if vim.api.nvim_win_get_buf(origin.win) ~= origin.buf then
      vim.api.nvim_win_set_buf(origin.win, origin.buf)
    end
    local line_count = vim.api.nvim_buf_line_count(origin.buf)
    local row = math.min(origin.cursor[1], line_count)
    local line = vim.api.nvim_buf_get_lines(origin.buf, row - 1, row, false)[1] or ""
    vim.api.nvim_win_set_cursor(origin.win, { row, math.min(origin.cursor[2], #line) })
    vim.fn.winrestview(origin.view)
  end
  local count = vim.v.count
  local register = vim.v.register
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)

  local target = character_target(opts)
  if target == nil then
    return
  end
  M.move(target)

  local motion = read_motion()
  if motion == nil then
    restore()
    return
  end

  local command = {}
  if register ~= "" and register ~= '"' then
    command[#command + 1] = '"' .. register
  end
  if count > 0 then
    command[#command + 1] = tostring(count)
  end
  command[#command + 1] = operator
  command[#command + 1] = motion

  local ok, err = pcall(vim.cmd.normal, { vim.keycode(table.concat(command)), bang = true })
  if not ok then
    restore()
    error(err)
  end

  if vim.api.nvim_get_mode().mode:sub(1, 1) == "i" then
    vim.api.nvim_create_autocmd("InsertLeave", { once = true, callback = restore })
  else
    restore()
  end
end

---@param opts? { char?: string, input?: fun(): string? }
function M.treesitter_search(opts)
  opts = opts or {}
  local char = opts.char or read_key()
  if is_cancel(char) then
    return
  end
  local items = type(targets.treesitter_search) == "function" and targets.treesitter_search(char) or {}
  local target = pick(items, opts.input)
  if target then
    M.select_node(target)
  end
end

---@return boolean
function M.search_enabled()
  return search_labels_enabled
end

---@return boolean
function M.toggle_search()
  search_labels_enabled = not search_labels_enabled
  if not search_labels_enabled then
    render.clear()
  end
  return search_labels_enabled
end

function M.setup()
  utils.map({ "n", "x", "o" }, "s", M.jump, { desc = "OneBeer Jump" })
  utils.map({ "n", "x", "o" }, "S", M.treesitter, { desc = "OneBeer Treesitter Jump" })
  utils.map("o", "r", M.remote, { desc = "OneBeer Remote" })
  utils.map({ "o", "x" }, "R", M.treesitter_search, { desc = "OneBeer Treesitter Search" })
  utils.map("c", "<C-s>", M.toggle_search, { desc = "Toggle OneBeer Search Labels" })
end

return M
