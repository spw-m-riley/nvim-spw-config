---@class onebeer.mule.Diagnostics
local M = {}

---@param title string
---@param items table[]
---@return nil
function M.set_quickfix(title, items)
  vim.fn.setqflist({}, " ", {
    items = items,
    title = title,
  })
end

return M
