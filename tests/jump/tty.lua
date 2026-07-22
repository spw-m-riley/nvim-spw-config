dofile(vim.fn.getcwd() .. "/tests/jump/minimal_init.lua")
dofile(vim.fn.getcwd() .. "/lua/onebeer/autocmds/init.lua")

local jump = require("onebeer.jump")
local render = require("onebeer.jump.render")

local function assert_true(name, condition)
  if not condition then
    error(name, 0)
  end
end

local function scratch(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  return buf
end

local function feed(keys)
  vim.api.nvim_feedkeys(vim.keycode(keys), "xt", false)
end

local ok, err = xpcall(function()
  jump.setup()

  scratch({ "one x two x three" })
  feed("sxa")
  assert_true("normal jump", vim.api.nvim_win_get_cursor(0)[2] == 4)

  scratch({ "one x two x three" })
  feed("dsxa")
  assert_true("operator jump", vim.api.nvim_get_current_line() == "x two x three")

  scratch({ "one x two" })
  feed("yrxaiw")
  assert_true("remote yank", vim.wait(1000, function()
    return vim.fn.getreg("0") == "x"
  end))
  assert_true("remote restore", vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }))

  scratch({ "one x two x three" })
  feed("vsxa")
  assert_true("visual jump", vim.api.nvim_get_mode().mode == "v" and vim.api.nvim_win_get_cursor(0)[2] == 4)
  feed("<Esc>")

  local buf = scratch({ "alpha beta", "alphabet" })
  vim.api.nvim_input("/alpha")
  assert_true("forward search entered", vim.wait(500, function()
    return vim.fn.getcmdtype() == "/"
  end))
  assert_true("forward search labels", #vim.api.nvim_buf_get_extmarks(buf, render.namespace(), 0, -1, {}) == 2)
  vim.api.nvim_input(vim.keycode("<Esc>"))
  assert_true("forward cleanup", vim.wait(500, function()
    return #vim.api.nvim_buf_get_extmarks(buf, render.namespace(), 0, -1, {}) == 0
  end))

  vim.api.nvim_input("?alpha")
  assert_true("backward search entered", vim.wait(500, function()
    return vim.fn.getcmdtype() == "?"
  end))
  assert_true("backward search labels", #vim.api.nvim_buf_get_extmarks(buf, render.namespace(), 0, -1, {}) == 2)
  vim.api.nvim_input(vim.keycode("<Esc>"))
  assert_true("backward cleanup", vim.wait(500, function()
    return #vim.api.nvim_buf_get_extmarks(buf, render.namespace(), 0, -1, {}) == 0
  end))
end, debug.traceback)

if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd.cquit()
end

print("TTY_PASS=1")
vim.cmd.qa({ bang = true })
