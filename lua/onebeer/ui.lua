---OneBeer UI helpers for consistent float styling (config-local).
---@class OneBeerUI
local M = {}
local has_devicons, devicons = pcall(require, "nvim-web-devicons")

---@alias OneBeerUIFloatKind "notification"|"history"

---@class OneBeerUIFloatPreviewOpts
---@field border? string
---@field winhighlight? string

---@class OneBeerUIFloatWinOpts
---@field border? string
---@field title_pos? string
---@field winblend? integer
---@field winhighlight? string
---@field preview? OneBeerUIFloatPreviewOpts

---@class OneBeerUISnacksWindowOpts
---@field winhighlight? string
---@field winblend? integer
---@field wrap? boolean
---@field conceallevel? integer
---@field colorcolumn? string

---@class OneBeerUISnacksFloatStyleOpts
---@field border? string
---@field wo? OneBeerUISnacksWindowOpts

---@type OneBeerUIFloatWinOpts
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

---@type OneBeerUIFloatPreviewOpts
local base_preview_opts = {
  border = "rounded",
  winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder",
}

---Return window opts with consistent float styling.
---@param opts? OneBeerUIFloatWinOpts
---@return OneBeerUIFloatWinOpts
M.float_winopts = function(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  if type(opts.preview) == "table" then
    opts.preview = vim.tbl_deep_extend("force", {}, base_preview_opts, opts.preview)
  end
  return vim.tbl_deep_extend("force", {}, base_float_opts, opts)
end

---@type OneBeerUISnacksWindowOpts
local base_snacks_wo = {
  winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder",
}

---@type OneBeerUISnacksWindowOpts
local base_notification_wo = vim.tbl_deep_extend("force", {}, base_snacks_wo, {
  winblend = 0,
  wrap = false,
  conceallevel = 2,
  colorcolumn = "",
})

---Helper to style Snacks float windows consistently.
---@param opts? OneBeerUISnacksFloatStyleOpts
---@param kind? OneBeerUIFloatKind
---@return OneBeerUISnacksFloatStyleOpts
M.snacks_float_style = function(opts, kind)
  local wo_defaults = kind == "notification" and base_notification_wo or base_snacks_wo
  return vim.tbl_deep_extend("force", {
    border = "rounded",
    wo = wo_defaults,
  }, opts or {})
end

---@param text string
---@return string
function M.escape_statusline(text)
  return text:gsub("%%", "%%%%")
end

---Render a styled native winbar with icon + path + state markers.
---@return string
M.winbar = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local bt = vim.bo[bufnr].buftype
  local ft = vim.bo[bufnr].filetype
  if (bt ~= "" and bt ~= "acwrite") or ft == "minifiles" or ft == "snacks_dashboard" then
    return ""
  end

  local full = vim.api.nvim_buf_get_name(bufnr)
  local path = full == "" and "[No Name]" or vim.fn.fnamemodify(full, ":~:.")
  local tail = full == "" and "" or vim.fn.fnamemodify(full, ":t")
  local icon = " "
  local icon_hl = "OneBeerWinbarIcon"

  if has_devicons then
    local maybe_icon, maybe_hl = devicons.get_icon(tail, nil, { default = true })
    if maybe_icon and maybe_icon ~= "" then
      icon = maybe_icon .. " "
    end
    if maybe_hl and maybe_hl ~= "" then
      icon_hl = maybe_hl
    end
  end

  local modified = vim.bo[bufnr].modified and "%#OneBeerWinbarModified# ●" or ""
  local readonly = vim.bo[bufnr].readonly and "%#OneBeerWinbarReadonly# " or ""
  return table.concat({
    "%=",
    "%#",
    icon_hl,
    "# ",
    icon,
    "%#OneBeerWinbarPath#",
    M.escape_statusline(path),
    modified,
    readonly,
    " %#WinBar#",
  })
end

return M
