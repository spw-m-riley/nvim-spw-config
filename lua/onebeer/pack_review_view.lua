---@module "onebeer.pack_review_view"
local ui = require("onebeer.ui")
local ns = vim.api.nvim_create_namespace("onebeer.pack_review")

---@class onebeer.PackReviewRow
---@field id? string
---@field name string
---@field summary? string
---@field status? string
---@field details? string[]|string

---@alias onebeer.PackReviewPhase "loading"|"ready"|"applying"|"error"|"done"

---@class onebeer.PackReviewState
---@field phase? onebeer.PackReviewPhase
---@field title? string
---@field message? string|string[]
---@field rows? onebeer.PackReviewRow[]
---@field on_apply? fun(ctx: onebeer.PackReviewCtx, state: onebeer.PackReviewState)
---@field on_cancel? fun(ctx: onebeer.PackReviewCtx, state: onebeer.PackReviewState)

---@class onebeer.PackReviewCtx
---@field buf integer
---@field win integer
---@field state onebeer.PackReviewState
---@field expanded table<string, boolean>
---@field line_to_row table<integer, string>

local M = {}

---@param phase onebeer.PackReviewPhase|nil
---@return string
local function phase_highlight(phase)
  if phase == "error" then
    return "OneBeerPackReviewPhaseError"
  end
  if phase == "applying" then
    return "OneBeerPackReviewPhaseApplying"
  end
  if phase == "done" then
    return "OneBeerPackReviewPhaseDone"
  end
  if phase == "ready" then
    return "OneBeerPackReviewPhaseReady"
  end
  return "OneBeerPackReviewPhaseLoading"
end

---@param status string|nil
---@return string
local function status_highlight(status)
  if status == "Error" then
    return "OneBeerPackReviewStatusError"
  end
  if status == "Done" then
    return "OneBeerPackReviewStatusDone"
  end
  if status == "Update" then
    return "OneBeerPackReviewStatusUpdate"
  end
  return "OneBeerPackReviewStatusSame"
end

---@param status string|nil
---@return string
local function row_name_highlight(status)
  if status == "Error" then
    return "OneBeerPackReviewRowNameError"
  end
  if status == "Done" then
    return "OneBeerPackReviewRowNameDone"
  end
  if status == "Update" then
    return "OneBeerPackReviewRowNameUpdate"
  end
  return "OneBeerPackReviewRowNameSame"
end

---@param status string|nil
---@return string
local function summary_highlight(status)
  if status == "Error" then
    return "OneBeerPackReviewSummaryError"
  end
  if status == "Done" then
    return "OneBeerPackReviewSummaryDone"
  end
  if status == "Update" then
    return "OneBeerPackReviewSummaryUpdate"
  end
  return "OneBeerPackReviewSummarySame"
end

---@param phase onebeer.PackReviewPhase|nil
---@return string
local function action_line(phase)
  if phase == "ready" then
    return " <CR> toggle details   u apply   q close"
  end
  if phase == "applying" then
    return " <CR> toggle details   q close   updating..."
  end
  if phase == "done" then
    return " <CR> toggle details   q close"
  end
  if phase == "error" then
    return " <CR> toggle details   q close"
  end
  return " <CR> toggle details   q close   loading..."
end

---@param line string
---@return boolean
local function is_row_line(line)
  return vim.startswith(line, " ▸ ") or vim.startswith(line, " ▾ ")
end

---@param buf integer
---@param line integer
---@param start_col integer
---@param end_col integer
---@param hl string
local function highlight_range(buf, line, start_col, end_col, hl)
  vim.api.nvim_buf_set_extmark(buf, ns, line - 1, start_col, {
    end_row = line - 1,
    end_col = end_col,
    hl_group = hl,
  })
end

---@param buf integer
---@param line integer
---@param text string
---@param prefix string
---@param label_hl string
---@param value_hl string
local function highlight_labeled_detail(buf, line, text, prefix, label_hl, value_hl)
  if not vim.startswith(text, prefix) then
    return
  end
  local start_col = 4
  local label_end = start_col + #prefix
  highlight_range(buf, line, start_col, label_end, label_hl)
  highlight_range(buf, line, label_end, #text, value_hl)
end

---@param buf integer
---@param line integer
local function highlight_action_line(buf, line)
  local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1]
  if text == nil then
    return
  end

  local spans = {
    { "<CR>", "OneBeerPackReviewActionKey" },
    { "toggle details", "OneBeerPackReviewActionText" },
    { "u", "OneBeerPackReviewActionKey" },
    { "apply", "OneBeerPackReviewActionText" },
    { "q", "OneBeerPackReviewActionKey" },
    { "close", "OneBeerPackReviewActionText" },
    { "loading...", "OneBeerPackReviewActionText" },
    { "updating...", "OneBeerPackReviewActionText" },
  }

  local search_from = 1
  for _, span in ipairs(spans) do
    local start_at = text:find(span[1], search_from, true)
    if start_at ~= nil then
      local start_col = start_at - 1
      local end_col = start_col + #span[1]
      highlight_range(buf, line, start_col, end_col, span[2])
      search_from = start_at + #span[1]
    end
  end
end

---@param opts table<string, any>|nil
---@return table<string, any>, table<string, any>
local function split_float_opts(opts)
  local win_opts = vim.tbl_deep_extend("force", {}, opts or {})
  local config = {
    border = win_opts.border,
    title_pos = win_opts.title_pos,
  }
  win_opts.border = nil
  win_opts.title_pos = nil
  win_opts.preview = nil
  return config, win_opts
end

---@param value string|string[]|nil
---@return string[]
local function to_lines(value)
  if value == nil then
    return {}
  end
  if type(value) == "table" then
    return value
  end
  return vim.split(value, "\n", { plain = true, trimempty = true })
end

---@param row onebeer.PackReviewRow
---@param index integer
---@return string
local function row_key(row, index)
  return row.id or row.name or tostring(index)
end

---@param phase onebeer.PackReviewPhase|nil
---@return string
local function phase_label(phase)
  if phase == "error" then
    return "Error"
  end
  if phase == "applying" then
    return "Applying"
  end
  if phase == "done" then
    return "Done"
  end
  if phase == "ready" then
    return "Ready"
  end
  return "Loading"
end

---@param state onebeer.PackReviewState|nil
---@return onebeer.PackReviewState
local function normalize_state(state)
  state = state or {}
  local rows = state.rows or {}
  local phase = state.phase or "loading"
  local message = state.message
  if message == nil and phase == "loading" then
    message = "Checking for plugin updates..."
  end
  return vim.tbl_deep_extend("force", {
    title = "Pack review",
    phase = phase,
    rows = rows,
    message = message,
  }, state)
end

---@param ctx onebeer.PackReviewCtx
local function prune_expanded(ctx)
  local keep = {}
  for i, row in ipairs(ctx.state.rows or {}) do
    keep[row_key(row, i)] = true
  end
  for key, _ in pairs(ctx.expanded) do
    if not keep[key] then
      ctx.expanded[key] = nil
    end
  end
end

---@param ctx onebeer.PackReviewCtx
---@param row onebeer.PackReviewRow
---@param index integer
---@param lines string[]
local function append_row(ctx, row, index, lines)
  local key = row_key(row, index)
  local expanded = ctx.expanded[key] == true
  local marker = expanded and "▾" or "▸"
  local status = row.status and (" [" .. row.status .. "]") or ""
  local summary = row.summary and (" - " .. row.summary) or ""
  lines[#lines + 1] = table.concat({ " ", marker, " ", row.name, status, summary })
  ctx.line_to_row[#lines] = key

  if not expanded then
    return
  end

  local details = to_lines(row.details)
  if #details == 0 then
    details = { "(no details)" }
  end
  for _, line in ipairs(details) do
    lines[#lines + 1] = "    " .. line
  end
end

---@param ctx onebeer.PackReviewCtx
local function render(ctx)
  if not vim.api.nvim_buf_is_valid(ctx.buf) then
    return
  end

  ctx.line_to_row = {}
  prune_expanded(ctx)

  local state = ctx.state
  local phase_line = 1
  local lines = {
    string.format(" %s", phase_label(state.phase)),
  }

  for _, line in ipairs(to_lines(state.message)) do
    lines[#lines + 1] = " " .. line
  end

  lines[#lines + 1] = ""

  local rows = state.rows or {}
  if #rows == 0 then
    local empty = state.phase == "loading" and "Loading updates..." or "No plugin updates to review."
    lines[#lines + 1] = " " .. empty
  else
    for i, row in ipairs(rows) do
      append_row(ctx, row, i, lines)
    end
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = action_line(state.phase)

  vim.bo[ctx.buf].modifiable = true
  vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, lines)
  vim.bo[ctx.buf].modifiable = false
  vim.bo[ctx.buf].modified = false
  vim.api.nvim_buf_clear_namespace(ctx.buf, ns, 0, -1)

  highlight_range(ctx.buf, phase_line, 1, #lines[phase_line], phase_highlight(state.phase))
  for line_nr = 2, #lines - 2 do
    local line = lines[line_nr]
    if vim.trim(line) ~= "" then
      highlight_range(ctx.buf, line_nr, 1, #line, "OneBeerPackReviewMessage")
    end
  end

  for line_nr = 1, #lines do
    local line = lines[line_nr]
    if is_row_line(line) then
      highlight_range(ctx.buf, line_nr, 1, 4, "OneBeerPackReviewRowToggle")
      local name_start = 4
      local status_start = line:find(" [", 1, true)
      local summary_start = line:find(" - ", 1, true)
      local row_status = line:match("%[(.-)%]")
      local name_end = status_start and (status_start - 1) or (summary_start and (summary_start - 1) or #line)
      highlight_range(ctx.buf, line_nr, name_start, name_end, row_name_highlight(row_status))
      if status_start then
        local status_end = line:find("]", status_start, true)
        if status_end then
          highlight_range(ctx.buf, line_nr, status_start - 1, status_end, status_highlight(row_status))
        end
      end
      if summary_start then
        highlight_range(ctx.buf, line_nr, summary_start - 1, #line, summary_highlight(row_status))
      end
    elseif line:match("^    ") then
      local detail_value_hl = "OneBeerPackReviewDetailValue"
      for prev = line_nr - 1, 1, -1 do
        local prev_line = lines[prev]
        if prev_line and is_row_line(prev_line) then
          if prev_line:match("%[Same%]") then
            detail_value_hl = "OneBeerPackReviewDetailMuted"
          end
          break
        end
      end
      highlight_labeled_detail(ctx.buf, line_nr, line, "Path:", "OneBeerPackReviewDetailLabel", detail_value_hl)
      highlight_labeled_detail(ctx.buf, line_nr, line, "Source:", "OneBeerPackReviewDetailLabel", detail_value_hl)
      highlight_labeled_detail(
        ctx.buf,
        line_nr,
        line,
        "Revision before:",
        "OneBeerPackReviewDetailLabel",
        detail_value_hl
      )
      highlight_labeled_detail(
        ctx.buf,
        line_nr,
        line,
        "Revision after:",
        "OneBeerPackReviewDetailLabel",
        detail_value_hl
      )
      highlight_labeled_detail(ctx.buf, line_nr, line, "Revision:", "OneBeerPackReviewDetailLabel", detail_value_hl)
      if line:match("^    [><] ") then
        highlight_range(ctx.buf, line_nr, 4, #line, status_highlight("Update"))
      elseif line:match("^    %(no details%)") then
        highlight_range(ctx.buf, line_nr, 4, #line, "OneBeerPackReviewSummarySame")
      elseif detail_value_hl == "OneBeerPackReviewDetailMuted" then
        highlight_range(ctx.buf, line_nr, 4, #line, detail_value_hl)
      end
    end
  end

  highlight_action_line(ctx.buf, #lines)

  local title = string.format(" %s ", state.title or "Pack review")
  if vim.api.nvim_win_is_valid(ctx.win) then
    pcall(vim.api.nvim_set_option_value, "title", true, { win = ctx.win })
    pcall(vim.api.nvim_set_option_value, "winbar", "", { win = ctx.win })
    pcall(
      vim.api.nvim_win_set_config,
      ctx.win,
      vim.tbl_deep_extend("force", {
        title = title,
        title_pos = "center",
      }, vim.api.nvim_win_get_config(ctx.win))
    )
  end
end

---@param ctx onebeer.PackReviewCtx
---@return string|nil
local function row_key_at_cursor(ctx)
  local cursor = vim.api.nvim_win_get_cursor(ctx.win)
  return ctx.line_to_row[cursor[1]]
end

---@param ctx onebeer.PackReviewCtx
local function toggle_current_row(ctx)
  if not (vim.api.nvim_win_is_valid(ctx.win) and vim.api.nvim_buf_is_valid(ctx.buf)) then
    return
  end
  local key = row_key_at_cursor(ctx)
  if key == nil then
    return
  end
  ctx.expanded[key] = not ctx.expanded[key]
  render(ctx)
end

---@param ctx onebeer.PackReviewCtx
---@param reason? "cancel"
local function close_internal(ctx, reason)
  if reason == "cancel" and type(ctx.state.on_cancel) == "function" then
    ctx.state.on_cancel(ctx, ctx.state)
  end
  if vim.api.nvim_win_is_valid(ctx.win) then
    vim.api.nvim_win_close(ctx.win, true)
  end
end

---@param ctx onebeer.PackReviewCtx
local function apply_current(ctx)
  if type(ctx.state.on_apply) == "function" then
    ctx.state.on_apply(ctx, ctx.state)
    return
  end
  vim.notify("Pack apply is not wired yet", vim.log.levels.INFO, { title = "Pack review" })
end

---@param ctx onebeer.PackReviewCtx
local function attach_keymaps(ctx)
  vim.keymap.set("n", "<CR>", function()
    toggle_current_row(ctx)
  end, {
    buffer = ctx.buf,
    desc = "Toggle plugin details",
    silent = true,
  })

  vim.keymap.set("n", "u", function()
    apply_current(ctx)
  end, {
    buffer = ctx.buf,
    desc = "Apply plugin updates",
    silent = true,
  })

  vim.keymap.set("n", "q", function()
    close_internal(ctx, "cancel")
  end, {
    buffer = ctx.buf,
    desc = "Close review",
    silent = true,
  })
end

---@param buf integer
---@return integer, integer
local function dimensions_for(buf)
  local content_width = 0
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    content_width = math.max(content_width, vim.fn.strdisplaywidth(line))
  end

  local max_width = math.max(60, math.floor(vim.o.columns * 0.8))
  local width = math.min(max_width, math.max(60, content_width + 4))
  local max_height = math.max(10, math.floor(vim.o.lines * 0.7))
  local height = math.min(max_height, math.max(10, vim.api.nvim_buf_line_count(buf) + 2))

  return width, height
end

---@param state? onebeer.PackReviewState
---@return onebeer.PackReviewCtx
function M.open(state)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "onebeer_pack_review"
  vim.bo[buf].swapfile = false

  local ctx = {
    buf = buf,
    win = -1,
    state = normalize_state(state),
    expanded = {},
    line_to_row = {},
  }

  render(ctx)
  local width, height = dimensions_for(buf)
  local config_opts, win_opts = split_float_opts(ui.float_winopts())
  local win = vim.api.nvim_open_win(
    buf,
    true,
    vim.tbl_deep_extend("force", {
      relative = "editor",
      style = "minimal",
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      title = " Pack review ",
    }, config_opts)
  )

  ctx.win = win
  for key, value in pairs(win_opts) do
    pcall(vim.api.nvim_set_option_value, key, value, { win = win })
  end
  attach_keymaps(ctx)
  render(ctx)
  return ctx
end

---@param ctx onebeer.PackReviewCtx
---@param state onebeer.PackReviewState
function M.update(ctx, state)
  if not (ctx and vim.api.nvim_buf_is_valid(ctx.buf)) then
    return
  end

  local next_state = vim.tbl_deep_extend("force", {}, ctx.state or {}, normalize_state(state))
  if state.rows ~= nil then
    next_state.rows = state.rows
  end
  if state.message ~= nil then
    next_state.message = state.message
  end

  ctx.state = next_state
  render(ctx)

  if vim.api.nvim_win_is_valid(ctx.win) then
    local width, height = dimensions_for(ctx.buf)
    vim.api.nvim_win_set_config(
      ctx.win,
      vim.tbl_deep_extend("force", vim.api.nvim_win_get_config(ctx.win), {
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
      })
    )
  end
end

---@param ctx onebeer.PackReviewCtx
function M.close(ctx)
  if not ctx then
    return
  end
  close_internal(ctx)
end

return M
