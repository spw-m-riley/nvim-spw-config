---OneBeer UI helpers for consistent float styling (config-local).
---@class OneBeerUI
local M = {}

local base_float_opts = {
  border = "rounded",
  title_pos = "center",
  winblend = 0,
  winhighlight = table.concat({
    "NormalFloat:NormalFloat",
    "FloatBorder:FloatBorder",
    "FloatTitle:FloatTitle",
  }, ","),
}

local base_preview_opts = {
  border = "rounded",
  winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder",
}

---Return window opts with consistent float styling.
---@param opts? table
---@return table
M.float_winopts = function(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  if type(opts.preview) == "table" then
    opts.preview = vim.tbl_deep_extend("force", {}, base_preview_opts, opts.preview)
  end
  return vim.tbl_deep_extend("force", {}, base_float_opts, opts)
end

local base_snacks_wo = {
  winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder",
}

local base_notification_wo = vim.tbl_deep_extend("force", {}, base_snacks_wo, {
  winblend = 0,
  wrap = false,
  conceallevel = 2,
  colorcolumn = "",
})

---Helper to style Snacks float windows consistently.
---@param opts? table
---@param kind? "notification"|"history"
---@return table
M.snacks_float_style = function(opts, kind)
  local wo_defaults = kind == "notification" and base_notification_wo or base_snacks_wo
  return vim.tbl_deep_extend("force", {
    border = "rounded",
    wo = wo_defaults,
  }, opts or {})
end

return M
