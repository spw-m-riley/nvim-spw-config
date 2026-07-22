dofile(vim.fn.getcwd() .. "/lua/onebeer/autocmds/init.lua")

local jump = require("onebeer.jump")
local render = require("onebeer.jump.render")

local failures = {}
local seen = {}
local scenario = ""

local function reset(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.fn.setreg('"', "")
  vim.fn.setreg("0", "")
  render.clear()
end

local function check(name, condition)
  if not condition then
    failures[#failures + 1] = name
  end
end

jump.setup()

vim.api.nvim_create_autocmd("CursorMoved", {
  callback = function()
    local mode = vim.api.nvim_get_mode().mode
    local col = vim.api.nvim_win_get_cursor(0)[2]
    if mode == "v" and scenario == "visual" and col == 4 then
      seen.visual = true
    elseif mode == "v" and scenario == "treesitter_search" and col == 15 then
      seen.treesitter_search = true
    end
  end,
})

vim.api.nvim_create_autocmd("CmdlineChanged", {
  callback = function()
    local command = vim.fn.getcmdtype()
    if (command == "/" or command == "?")
      and #vim.api.nvim_buf_get_extmarks(0, render.namespace(), 0, -1, {}) == 2
    then
      seen[command] = true
    end
  end,
})

vim.api.nvim_create_user_command("OneBeerTtyReset", function(ctx)
  scenario = ctx.args
  if scenario == "treesitter" or scenario == "treesitter_search" then
    reset({ "local x = call(z)" })
    vim.bo.filetype = "lua"
    vim.treesitter.start(0, "lua")
  elseif scenario == "search" then
    reset({ "alpha beta", "alphabet" })
  else
    reset({ "one x two x three" })
  end
end, { nargs = 1 })

vim.api.nvim_create_user_command("OneBeerTtyCheck", function(ctx)
  local name = ctx.args
  if name == "normal" then
    check(name, vim.api.nvim_win_get_cursor(0)[2] == 4)
  elseif name == "operator" then
    check(name, vim.api.nvim_get_current_line() == "x two x three")
  elseif name == "remote" then
    check(name, vim.fn.getreg("0") == "x" and vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }))
  elseif name == "visual" then
    check(name, seen.visual == true)
  elseif name == "treesitter" then
    check(name, vim.api.nvim_win_get_cursor(0)[2] == 15)
  elseif name == "treesitter_search" then
    check(name, seen.treesitter_search == true)
  elseif name == "forward_search" then
    check(name, seen["/"] == true and #vim.api.nvim_buf_get_extmarks(0, render.namespace(), 0, -1, {}) == 0)
  elseif name == "backward_search" then
    check(name, seen["?"] == true and #vim.api.nvim_buf_get_extmarks(0, render.namespace(), 0, -1, {}) == 0)
  end
end, { nargs = 1 })

vim.api.nvim_create_user_command("OneBeerTtyFinish", function()
  if #failures > 0 then
    vim.api.nvim_err_writeln("TTY failures: " .. table.concat(failures, ", "))
    vim.cmd.cquit()
    return
  end
  print("TTY_PASS=8")
  vim.cmd.qa({ bang = true })
end, {})
