local labels = require("onebeer.jump.labels")
local render = require("onebeer.jump.render")
local targets = require("onebeer.jump.targets")

local M = {}

local label_alphabet = "asdfghjklqwertyuiopzxcvbnmASDFGHJKLQWERTYUIOPZXCVBNM0123456789"
local pending_target
local state

local function enabled()
  return require("onebeer.jump").search_enabled()
end

---@param value string?
---@return boolean
local function is_cancel(value)
  return value == nil
    or value == ""
    or value == "\027"
    or value == vim.keycode("<Esc>")
    or value == vim.keycode("<C-c>")
end

---@param pattern string
---@param count integer
---@return string?
local function safe_alphabet(pattern, count)
  local safe = {}
  local wanted = math.min(count, 12)
  for index = 0, vim.fn.strchars(label_alphabet) - 1 do
    local char = vim.fn.strcharpart(label_alphabet, index, 1)
    if #targets.search(pattern .. char) == 0 then
      safe[#safe + 1] = char
      if #safe >= wanted and (#safe > 1 or count == 1) then
        break
      end
    end
  end
  if #safe == 0 or (#safe == 1 and count > 1) then
    return nil
  end
  return table.concat(safe)
end

---@return string?
function M.choose()
  if state == nil then
    return nil
  end

  local candidates = state
  local prefix = ""
  while #candidates > 0 do
    local key = vim.fn.getcharstr()
    if is_cancel(key) then
      render.show(state)
      return ""
    end
    if key == vim.keycode("<C-s>") then
      require("onebeer.jump").toggle_search()
      return ""
    end

    prefix = prefix .. key
    candidates = vim.tbl_filter(function(target)
      return vim.startswith(target.label, prefix)
    end, candidates)
    if #candidates == 1 and candidates[1].label == prefix then
      pending_target = candidates[1]
      state = nil
      render.clear()
      return vim.keycode("<CR>")
    end

    render.show(candidates)
    vim.cmd.redraw()
  end
  return ""
end

function M.clear()
  state = nil
  render.clear()
  if pending_target then
    local target = pending_target
    pending_target = nil
    vim.schedule(function()
      require("onebeer.jump").move(target)
    end)
  end
end

---@param command string
---@param pattern string
local function update_items(command, pattern)
  local items = targets.search(pattern)
  if command == "?" then
    items = vim.fn.reverse(items)
  end
  local alphabet = safe_alphabet(pattern, #items)
  if alphabet == nil then
    return nil
  end
  local generated = #items == 1 and { alphabet:sub(1, 1) } or labels.generate(#items, alphabet)
  for index, target in ipairs(items) do
    target.label = generated[index]
  end
  return items
end

---@param command? string
---@param pattern? string
function M.update(command, pattern)
  command = command or vim.fn.getcmdtype()
  if not enabled() or (command ~= "/" and command ~= "?") then
    M.clear()
    return
  end

  pattern = pattern or vim.fn.getcmdline()
  if pattern == "" then
    M.clear()
    return
  end

  local items = update_items(command, pattern)
  if items == nil then
    M.clear()
    return
  end
  state = items
  render.show(items)
end

return M
