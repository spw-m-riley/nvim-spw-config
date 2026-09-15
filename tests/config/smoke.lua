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

check("native Treesitter bootstrap is eager", function()
  for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ event = "FileType" })) do
    if autocmd.group_name == "OneBeerTreesitter" then
      return true
    end
  end
  return false
end)

check("Treesitter starts on a regular filetype", function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.bo[buf].filetype = "lua"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local value = 1" })
  vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
  return vim.wait(500, function()
    return vim.b[buf].ts_highlight == true
  end)
end)

check("bash LSP keeps zsh support", function()
  return vim.tbl_contains(vim.lsp.config.bashls.filetypes or {}, "zsh")
end)

check("LSP formatting remains disabled by attach policy", function()
  return type(vim.lsp.config.yamlls.on_init) == "function" and type(vim.lsp.config.jsonls.on_init) == "function"
end)

check("backup and undo paths preserve absolute names", function()
  return vim.o.backupdir:sub(-2) == "//" and vim.o.undodir:sub(-2) == "//"
end)

if #failures > 0 then
  error(table.concat(failures, "\n"), 0)
end

print(("SMOKE_PASS=%d"):format(passed))
