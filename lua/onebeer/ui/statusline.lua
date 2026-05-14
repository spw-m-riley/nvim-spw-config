local ui = require("onebeer.ui")

local M = {}

local mode_labels = {
  n = { text = "NORMAL", hl = "OneBeerStatuslineModeNormal" },
  i = { text = "INSERT", hl = "OneBeerStatuslineModeInsert" },
  v = { text = "VISUAL", hl = "OneBeerStatuslineModeVisual" },
  V = { text = "V-LINE", hl = "OneBeerStatuslineModeVisual" },
  ["\22"] = { text = "V-BLOCK", hl = "OneBeerStatuslineModeVisual" },
  R = { text = "REPLACE", hl = "OneBeerStatuslineModeReplace" },
  c = { text = "COMMAND", hl = "OneBeerStatuslineModeCommand" },
  t = { text = "TERMINAL", hl = "OneBeerStatuslineModeTerminal" },
}

---@param parts string[]
---@param hl string
---@param text string
---@param escape? boolean
local function add_section(parts, hl, text, escape)
  if text == nil or text == "" then
    return
  end

  parts[#parts + 1] = "%#"
  parts[#parts + 1] = hl
  parts[#parts + 1] = "# "
  parts[#parts + 1] = escape == false and text or ui.escape_statusline(text)
  parts[#parts + 1] = " "
end

---@param parts string[]
local function add_separator(parts)
  parts[#parts + 1] = "%#OneBeerStatuslineMuted#│ "
end

---@return { text: string, hl: string }
local function mode_status()
  local mode = vim.api.nvim_get_mode().mode
  local label = mode_labels[mode] or mode_labels[mode:sub(1, 1)] or { text = mode, hl = "OneBeerStatuslineAccent" }
  return label
end

---@return string
local function git_branch_status()
  local branch = vim.b.gitsigns_head
  if not branch or branch == "" then
    local status = vim.b.gitsigns_status_dict
    if type(status) == "table" then
      branch = status.head
    end
  end
  if not branch or branch == "" then
    return ""
  end
  return " " .. branch
end

---@param compact boolean
---@return string
local function file_status(compact)
  local bufnr = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  local path = ""

  if name == "" then
    path = "[No Name]"
  elseif compact then
    path = vim.fn.fnamemodify(name, ":t")
  else
    path = vim.fn.fnamemodify(name, ":~:.")
  end

  local flags = {}
  if vim.bo[bufnr].modified then
    flags[#flags + 1] = "+"
  end
  if vim.bo[bufnr].readonly then
    flags[#flags + 1] = "RO"
  end

  if #flags == 0 then
    return path
  end

  return table.concat({ path, " [", table.concat(flags, ","), "]" })
end

---@return string, string
local function diagnostics_status()
  local sev = vim.diagnostic.severity
  local errors = #vim.diagnostic.get(0, { severity = sev.ERROR })
  local warns = #vim.diagnostic.get(0, { severity = sev.WARN })
  local hints = #vim.diagnostic.get(0, { severity = sev.HINT })

  if errors == 0 and warns == 0 and hints == 0 then
    return "", "OneBeerStatuslineMuted"
  end

  local parts = {}
  if errors > 0 then
    parts[#parts + 1] = "E" .. errors
  end
  if warns > 0 then
    parts[#parts + 1] = "W" .. warns
  end
  if hints > 0 then
    parts[#parts + 1] = "H" .. hints
  end

  local hl = "OneBeerStatuslineInfo"
  if errors > 0 then
    hl = "OneBeerStatuslineError"
  elseif warns > 0 then
    hl = "OneBeerStatuslineWarn"
  end

  return table.concat(parts, " "), hl
end

---@param width integer
---@return string
local function lsp_client_status(width)
  if width < 95 then
    return ""
  end

  local clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })
  if #clients == 0 then
    return ""
  end

  local names = {}
  for _, client in ipairs(clients) do
    names[#names + 1] = client.name
  end

  local joined = table.concat(names, ",")
  if width < 120 and #joined > 20 then
    return joined:sub(1, 20) .. "…"
  end
  return joined
end

---@param width integer
---@return string
local function progress_status(width)
  if width < 110 or not vim.ui or type(vim.ui.progress_status) ~= "function" then
    return ""
  end

  return vim.ui.progress_status()
end

---@return boolean
local function is_special_buffer()
  local bt = vim.bo.buftype
  if bt == "" or bt == "acwrite" then
    return false
  end
  return true
end

---@return string
function M.render()
  local width = vim.api.nvim_win_get_width(0)

  if is_special_buffer() then
    local parts = { " " }
    local filetype = vim.bo.filetype ~= "" and vim.bo.filetype or vim.bo.buftype
    add_section(parts, "OneBeerStatuslineMuted", filetype)
    parts[#parts + 1] = "%="
    add_section(parts, "OneBeerStatuslineSection", "%l:%c", false)
    parts[#parts + 1] = "%#StatusLine#"
    return table.concat(parts)
  end

  local parts = { " " }
  local mode = mode_status()
  local diagnostics_text, diagnostics_hl = diagnostics_status()
  local branch = width >= 80 and git_branch_status() or ""
  local lsp = lsp_client_status(width)
  local progress = progress_status(width)

  add_section(parts, mode.hl, mode.text)
  if branch ~= "" then
    add_separator(parts)
    add_section(parts, "OneBeerStatuslineAccent", branch)
  end
  add_separator(parts)
  add_section(parts, "OneBeerStatuslineSection", file_status(width < 120))

  parts[#parts + 1] = "%="

  if diagnostics_text ~= "" then
    add_section(parts, diagnostics_hl, diagnostics_text)
  end
  if lsp ~= "" then
    add_separator(parts)
    add_section(parts, "OneBeerStatuslineInfo", lsp)
  end
  if progress ~= "" then
    add_separator(parts)
    add_section(parts, "OneBeerStatuslineInfo", progress, false)
  end

  add_separator(parts)
  add_section(parts, "OneBeerStatuslineSection", "%3p%% %l:%c", false)
  parts[#parts + 1] = "%#StatusLine#"

  return table.concat(parts)
end

return M
