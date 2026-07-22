local failures = {}
local passed = 0

local function check(name, fn)
  local ok, result = pcall(fn)
  if ok and result ~= false then
    passed = passed + 1
    print("PASS " .. name)
    return
  end
  failures[#failures + 1] = name .. ": " .. tostring(result)
end

local function scratch(lines)
  while #vim.api.nvim_tabpage_list_wins(0) > 1 do
    local wins = vim.api.nvim_tabpage_list_wins(0)
    vim.api.nvim_win_close(wins[#wins], true)
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  return buf
end

local function feed(keys)
  vim.api.nvim_feedkeys(vim.keycode(keys), "xt", false)
end

check("fixed-width labels", function()
  local generated = require("onebeer.jump.labels").generate(5, "ab")
  return #generated == 5 and #generated[1] == #generated[5] and generated[1] ~= generated[2]
end)

check("multibyte character targets", function()
  scratch({ "aéa" })
  local items = require("onebeer.jump.targets").characters("a", { windows = { vim.api.nvim_get_current_win() } })
  return #items == 1 and items[1].col == 3
end)

check("multi-window targets", function()
  local first = scratch({ "x" })
  vim.cmd.vsplit()
  local second_win = vim.api.nvim_get_current_win()
  local second = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(second_win, second)
  vim.api.nvim_buf_set_lines(second, 0, -1, false, { "x" })
  vim.api.nvim_win_set_cursor(second_win, { 1, 0 })
  local items = require("onebeer.jump.targets").characters("x")
  vim.api.nvim_win_close(second_win, true)
  return #items == 1 and items[1].buf == first and items[1].buf ~= second
end)

check("overlay render and cleanup", function()
  local buf = scratch({ "target" })
  local render = require("onebeer.jump.render")
  render.show({ { buf = buf, win = vim.api.nvim_get_current_win(), row = 1, col = 0, label = "a" } })
  local shown = #vim.api.nvim_buf_get_extmarks(buf, render.namespace(), 0, -1, {}) == 1
  render.clear()
  return shown and #vim.api.nvim_buf_get_extmarks(buf, render.namespace(), 0, -1, {}) == 0
end)

check("label selection and movement", function()
  local jump = require("onebeer.jump")
  local buf = scratch({ "ab" })
  local keys = { "a", "b" }
  local index = 0
  local selected = jump.select({
    { label = "aa", buf = buf, win = vim.api.nvim_get_current_win(), row = 1, col = 0 },
    { label = "ab", buf = buf, win = vim.api.nvim_get_current_win(), row = 1, col = 1 },
  }, function()
    index = index + 1
    return keys[index]
  end)
  jump.move(selected)
  return vim.api.nvim_win_get_cursor(0)[2] == 1
end)

check("operator-pending motion", function()
  scratch({ "one x two x three" })
  require("onebeer.jump").setup()
  feed("dsxa")
  return vim.api.nvim_get_current_line() == "x two x three" and vim.api.nvim_get_mode().mode == "n"
end)

check("visual motion", function()
  scratch({ "one x two x three" })
  require("onebeer.jump").setup()
  feed("vsxa")
  local ok = vim.api.nvim_get_mode().mode == "v" and vim.api.nvim_win_get_cursor(0)[2] == 4
  feed("<Esc>")
  return ok
end)

check("remote operator motion", function()
  scratch({ "one x two" })
  require("onebeer.jump").setup()
  vim.defer_fn(function()
    vim.api.nvim_input("xaiw")
  end, 20)
  vim.api.nvim_input("yr")
  return vim.wait(1000, function()
    return vim.fn.getreg("0") == "x"
  end) and vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 })
end)

check("Treesitter node selection", function()
  scratch({ "local value = call(argument)" })
  vim.bo.filetype = "lua"
  if not pcall(vim.treesitter.start, 0, "lua") then
    return false
  end
  local items = require("onebeer.jump.targets").treesitter_search("argument", {
    windows = { vim.api.nvim_get_current_win() },
  })
  if #items ~= 1 then
    return false
  end
  require("onebeer.jump").select_node(items[1])
  local ok = vim.api.nvim_get_mode().mode == "v" and vim.api.nvim_win_get_cursor(0)[2] == items[1].end_col - 1
  feed("<Esc>")
  return ok
end)

check("search labels and invalid-pattern cleanup", function()
  local buf = scratch({ "alpha beta", "alphabet" })
  local render = require("onebeer.jump.render")
  local search = require("onebeer.jump.search")
  search.update("/", "alpha")
  if #vim.api.nvim_buf_get_extmarks(buf, render.namespace(), 0, -1, {}) ~= 2 then
    return false
  end
  search.update("/", "[")
  return #vim.api.nvim_buf_get_extmarks(buf, render.namespace(), 0, -1, {}) == 0
end)

check("startup keymaps", function()
  dofile(vim.fn.getcwd() .. "/lua/onebeer/keymaps/init.lua").defaults()
  return vim.fn.maparg("s", "n", false, true).desc == "OneBeer Jump"
    and vim.fn.maparg("r", "o", false, true).desc == "OneBeer Remote"
end)

if #failures > 0 then
  error(table.concat(failures, "\n"), 0)
end

print(("SMOKE_PASS=%d"):format(passed))
