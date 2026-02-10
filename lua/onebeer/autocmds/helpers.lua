---@class onebeer.autocmds.helpers
local M = {}

---Create an autocmd group with sensible defaults.
---@param name string
---@param opts? table
---@return integer
function M.create_group(name, opts)
  local options = { clear = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  return vim.api.nvim_create_augroup(name, options)
end

---Create an autocmd.
---@param event string|string[]
---@param opts table
---@return integer
function M.create_autocmd(event, opts)
  return vim.api.nvim_create_autocmd(event, opts)
end

---Create a user command.
---@param name string
---@param rhs string|function
---@param opts? table
---@return integer
function M.create_command(name, rhs, opts)
  return vim.api.nvim_create_user_command(name, rhs, opts or {})
end

return M
