local ui = require("onebeer.ui")

local M = {}

---@param parts string[]
---@param text string
---@param escape? boolean
local function add_section(parts, text, escape)
  if text == "" then
    return
  end

  parts[#parts + 1] = escape == false and text or ui.escape_statusline(text)
  parts[#parts + 1] = " "
end

---@return string
local function diagnostics_status()
  if type(vim.diagnostic.status) ~= "function" then
    return ""
  end

  return vim.diagnostic.status()
end

---@return string
local function progress_status()
  if not vim.ui or type(vim.ui.progress_status) ~= "function" then
    return ""
  end

  return vim.ui.progress_status()
end

---@return string
local function lsp_client_status()
  local clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })
  local names = {}

  for _, client in ipairs(clients) do
    names[#names + 1] = client.name
  end

  return table.concat(names, ",")
end

---@return string
function M.render()
  local parts = { " " }

  add_section(parts, diagnostics_status(), false)
  add_section(parts, progress_status(), false)
  add_section(parts, lsp_client_status())

  parts[#parts + 1] = "%=%f %l:%c "

  return table.concat(parts)
end

return M
