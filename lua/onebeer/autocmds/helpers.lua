---@class onebeer.autocmds.helpers
local M = {}

---@alias OneBeerAutocmdEvent string|string[]
---@alias OneBeerUserCommandRhs string|function

---Create an autocmd group with sensible defaults.
---@param name string
---@param opts? vim.api.keyset.create_augroup
---@return integer
function M.create_group(name, opts)
  local options = { clear = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  return vim.api.nvim_create_augroup(name, options)
end

---Create an autocmd.
---@param event OneBeerAutocmdEvent
---@param opts vim.api.keyset.create_autocmd
---@return integer
function M.create_autocmd(event, opts)
  return vim.api.nvim_create_autocmd(event, opts)
end

---Create a user command.
---@param name string
---@param rhs OneBeerUserCommandRhs
---@param opts? vim.api.keyset.user_command
---@return nil
function M.create_command(name, rhs, opts)
  return vim.api.nvim_create_user_command(name, rhs, opts or {})
end

return M
