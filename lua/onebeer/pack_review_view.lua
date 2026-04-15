---@module "onebeer.pack_review_view"
local ui = require("onebeer.ui")
local ns = vim.api.nvim_create_namespace("onebeer.pack_review")

---@class onebeer.PackReviewRow
---@field id? string
---@field name string
---@field summary? string
---@field status? onebeer.PackReviewRowStatus
---@field details? string[]|string

---@alias onebeer.PackReviewPhase "loading"|"ready"|"applying"|"error"|"done"
---@alias onebeer.PackReviewRowStatus "Queued"|"Checking"|"Applying"|"Done"|"Error"|"Update"|"Same"

---@class onebeer.PackReviewProgress
---@field phase_label string
---@field percent? integer
---@field current? string
---@field active_row_id? string
---@field indeterminate? boolean
---@field spinner? boolean

---@class onebeer.PackReviewState
---@field phase? onebeer.PackReviewPhase
---@field title? string
---@field progress? onebeer.PackReviewProgress
---@field message? string|string[]
---@field rows? onebeer.PackReviewRow[]
---@field on_apply? fun(ctx: onebeer.PackReviewCtx, state: onebeer.PackReviewState)
---@field on_cancel? fun(ctx: onebeer.PackReviewCtx, state: onebeer.PackReviewState)

---@class onebeer.PackReviewLayout
---@field width integer
---@field height integer
---@field row integer
---@field col integer
---@field phase onebeer.PackReviewPhase
---@field rows_signature string

---@class onebeer.PackReviewCtx
---@field buf integer
---@field win integer
---@field state onebeer.PackReviewState
---@field expanded table<string, boolean>
---@field line_to_row table<integer, string>
---@field layout? onebeer.PackReviewLayout

local M = {}
local progress_bar_width = 14
local spinner_icon = "⟳"
local dimensions_for

local status_palette = {
  Queued = {
    status = "OneBeerPackReviewStatusQueued",
    name = "OneBeerPackReviewRowNameQueued",
    summary = "OneBeerPackReviewSummaryQueued",
  },
  Checking = {
    status = "OneBeerPackReviewStatusChecking",
    name = "OneBeerPackReviewRowNameChecking",
    summary = "OneBeerPackReviewSummaryChecking",
  },
  Applying = {
    status = "OneBeerPackReviewStatusApplying",
    name = "OneBeerPackReviewRowNameApplying",
    summary = "OneBeerPackReviewSummaryApplying",
  },
  Done = {
    status = "OneBeerPackReviewStatusDone",
    name = "OneBeerPackReviewRowNameDone",
    summary = "OneBeerPackReviewSummaryDone",
  },
  Error = {
    status = "OneBeerPackReviewStatusError",
    name = "OneBeerPackReviewRowNameError",
    summary = "OneBeerPackReviewSummaryError",
  },
  Update = {
    status = "OneBeerPackReviewStatusUpdate",
    name = "OneBeerPackReviewRowNameUpdate",
    summary = "OneBeerPackReviewSummaryUpdate",
  },
  Same = {
    status = "OneBeerPackReviewStatusSame",
    name = "OneBeerPackReviewRowNameSame",
    summary = "OneBeerPackReviewSummarySame",
  },
}

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
  return (status_palette[status] or status_palette.Same).status
end

---@param status string|nil
---@return string
local function row_name_highlight(status)
  return (status_palette[status] or status_palette.Same).name
end

---@param status string|nil
---@return string
local function summary_highlight(status)
  return (status_palette[status] or status_palette.Same).summary
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
---@param start_col integer 0-based, end-exclusive extmark column
---@param end_col integer 0-based, end-exclusive extmark column
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

---@param text string
---@param max_width integer
---@return string
local function truncate_text(text, max_width)
  if max_width <= 0 or vim.fn.strdisplaywidth(text) <= max_width then
    return text
  end
  if max_width == 1 then
    return "…"
  end
  return vim.fn.strcharpart(text, 0, max_width - 1) .. "…"
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

---@param progress onebeer.PackReviewProgress|nil
---@param phase onebeer.PackReviewPhase
---@return onebeer.PackReviewProgress
local function normalize_progress(progress, phase)
  local defaults = {
    phase_label = phase_label(phase),
    percent = (phase == "ready" or phase == "done") and 100 or nil,
    indeterminate = phase == "loading" or phase == "applying",
    spinner = phase == "loading" or phase == "applying",
  }
  local next_progress = vim.tbl_deep_extend("force", defaults, progress or {})
  if next_progress.indeterminate then
    next_progress.percent = nil
  elseif next_progress.percent ~= nil then
    next_progress.percent = math.max(0, math.min(100, next_progress.percent))
  end
  return next_progress
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
    progress = normalize_progress(state and state.progress, phase),
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

---@return string
local function empty_rows_message(phase)
  if phase == "loading" then
    return "Loading updates..."
  end
  return "No plugin updates to review."
end

---@param progress onebeer.PackReviewProgress
---@param width integer|nil
---@return string
local function progress_line_text(progress, width)
  if progress.indeterminate then
    local indicator = progress.spinner and spinner_icon or "•"
    local text = progress.current or "Waiting for progress updates..."
    if width ~= nil then
      text = truncate_text(text, math.max(0, width - 4))
    end
    return table.concat({ " ", indicator, " ", text })
  end

  local percent = progress.percent or 0
  local filled = math.floor((percent / 100) * progress_bar_width + 0.5)
  local bar = string.rep("=", filled) .. string.rep("-", progress_bar_width - filled)
  local current = progress.current and (" " .. progress.current) or ""
  local line = (" [%s] %3d%%"):format(bar, percent) .. current
  if width ~= nil then
    line = truncate_text(line, math.max(0, width - 2))
  end
  return " " .. line
end

---@param progress_text string
---@param progress onebeer.PackReviewProgress
---@return { bar_start: integer, bar_end: integer, percent_start: integer|nil, percent_end: integer|nil, current_start: integer|nil }|nil
local function progress_highlight_columns(progress_text, progress)
  local open_bracket = progress_text:find("[", 1, true)
  local close_bracket = open_bracket and progress_text:find("]", open_bracket, true) or nil
  if not open_bracket or not close_bracket then
    return nil
  end

  local percent_start, percent_end = progress_text:find("%d+%%", close_bracket + 1)
  local current_start
  if progress.current then
    current_start = progress_text:find(progress.current, close_bracket + 1, true)
  end

  return {
    bar_start = open_bracket,
    bar_end = close_bracket - 1,
    percent_start = percent_start and (percent_start - 1) or nil,
    percent_end = percent_end or nil,
    current_start = current_start and (current_start - 1) or nil,
  }
end

---@class onebeer.PackReviewHeaderMeta
---@field title_line integer
---@field phase_line integer
---@field progress_line integer
---@field message_start integer
---@field message_end integer

---@param ctx onebeer.PackReviewCtx
---@param lines string[]
---@return onebeer.PackReviewHeaderMeta
local function append_header_block(ctx, lines)
  local state = ctx.state
  local message_lines = to_lines(state.message)
  if state.progress and state.progress.current then
    local filtered = {}
    for _, line in ipairs(message_lines) do
      if vim.trim(line) ~= vim.trim(state.progress.current) then
        filtered[#filtered + 1] = line
      end
    end
    message_lines = filtered
  end
  local width = ctx.layout and ctx.layout.width or nil
  local header = {
    title_line = #lines + 1,
    phase_line = #lines + 2,
    progress_line = #lines + 3,
    message_start = #lines + 4,
    message_end = #lines + 3,
  }

  lines[#lines + 1] = " " .. (state.title or "Pack review")
  lines[#lines + 1] = " " .. state.progress.phase_label
  lines[#lines + 1] = progress_line_text(state.progress, width)
  for _, line in ipairs(message_lines) do
    lines[#lines + 1] = " " .. line
  end
  header.message_end = #lines
  lines[#lines + 1] = ""
  return header
end

---@param rows onebeer.PackReviewRow[]|nil
---@return string
local function rows_signature(rows)
  local signature = {}
  for i, row in ipairs(rows or {}) do
    signature[#signature + 1] = table.concat({
      row_key(row, i),
      row.name or "",
      tostring(#to_lines(row.details)),
    }, ":")
  end
  return table.concat(signature, "|")
end

---@param width integer
---@param height integer
---@return integer, integer
local function centered_position(width, height)
  return math.floor((vim.o.lines - height) / 2), math.floor((vim.o.columns - width) / 2)
end

---@param ctx onebeer.PackReviewCtx
---@return onebeer.PackReviewLayout
local function compute_layout(ctx)
  local width, height = dimensions_for(ctx.buf)
  local row, col = centered_position(width, height)
  return {
    width = width,
    height = height,
    row = row,
    col = col,
    phase = ctx.state.phase,
    rows_signature = rows_signature(ctx.state.rows),
  }
end

---@param ctx onebeer.PackReviewCtx
---@return boolean
local function should_refresh_layout(ctx)
  if ctx.layout == nil then
    return true
  end
  return ctx.layout.phase ~= ctx.state.phase or ctx.layout.rows_signature ~= rows_signature(ctx.state.rows)
end

---@param ctx onebeer.PackReviewCtx
local function refresh_layout(ctx)
  ctx.layout = compute_layout(ctx)
  if not vim.api.nvim_win_is_valid(ctx.win) then
    return
  end
  vim.api.nvim_win_set_config(
    ctx.win,
    vim.tbl_deep_extend("force", vim.api.nvim_win_get_config(ctx.win), {
      width = ctx.layout.width,
      height = ctx.layout.height,
      row = ctx.layout.row,
      col = ctx.layout.col,
    })
  )
end

---@param ctx onebeer.PackReviewCtx
local function render(ctx)
  if not vim.api.nvim_buf_is_valid(ctx.buf) then
    return
  end

  ctx.line_to_row = {}
  prune_expanded(ctx)

  local state = ctx.state
  local lines = {}
  local header = append_header_block(ctx, lines)

  local rows = state.rows or {}
  if #rows == 0 then
    lines[#lines + 1] = " " .. empty_rows_message(state.phase)
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

  highlight_range(ctx.buf, header.title_line, 1, #lines[header.title_line], "OneBeerPackReviewHeaderTitle")
  highlight_range(ctx.buf, header.phase_line, 1, #lines[header.phase_line], phase_highlight(state.phase))
  local progress_text = lines[header.progress_line]
  if state.progress.indeterminate then
    local indicator_width = #(state.progress.spinner and spinner_icon or "•")
    highlight_range(ctx.buf, header.progress_line, 1, 1 + indicator_width, "OneBeerPackReviewProgressSpinner")
    local current_start = indicator_width + 2
    if #progress_text >= current_start then
      highlight_range(ctx.buf, header.progress_line, current_start, #progress_text, "OneBeerPackReviewHeaderCurrent")
    end
  else
    local columns = progress_highlight_columns(progress_text, state.progress)
    if columns ~= nil then
      local fill = math.floor(((state.progress.percent or 0) / 100) * progress_bar_width + 0.5)
      if fill > 0 then
        highlight_range(
          ctx.buf,
          header.progress_line,
          columns.bar_start,
          math.min(columns.bar_start + fill, columns.bar_end),
          "OneBeerPackReviewProgressBarFill"
        )
      end
      if fill < progress_bar_width then
        highlight_range(
          ctx.buf,
          header.progress_line,
          columns.bar_start + fill,
          columns.bar_end,
          "OneBeerPackReviewProgressBarTrack"
        )
      end
      if columns.percent_start and columns.percent_end then
        highlight_range(
          ctx.buf,
          header.progress_line,
          columns.percent_start,
          columns.percent_end,
          "OneBeerPackReviewProgressPercent"
        )
      end
      if columns.current_start and #progress_text >= columns.current_start then
        highlight_range(
          ctx.buf,
          header.progress_line,
          columns.current_start,
          #progress_text,
          "OneBeerPackReviewHeaderCurrent"
        )
      end
    end
  end

  for line_nr = header.message_start, header.message_end do
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
dimensions_for = function(buf)
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
    layout = nil,
  }

  render(ctx)
  ctx.layout = compute_layout(ctx)
  local config_opts, win_opts = split_float_opts(ui.float_winopts())
  local win = vim.api.nvim_open_win(
    buf,
    true,
    vim.tbl_deep_extend("force", {
      relative = "editor",
      style = "minimal",
      width = ctx.layout.width,
      height = ctx.layout.height,
      row = ctx.layout.row,
      col = ctx.layout.col,
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

  local merged_state = vim.tbl_deep_extend("force", {}, ctx.state or {}, state)
  if state.rows ~= nil then
    merged_state.rows = state.rows
  end
  if state.message ~= nil then
    merged_state.message = state.message
  end
  if state.phase ~= nil and state.progress == nil then
    merged_state.progress = nil
  end

  ctx.state = normalize_state(merged_state)
  local layout_needs_refresh = should_refresh_layout(ctx)
  if layout_needs_refresh then
    ctx.layout = nil
  end
  render(ctx)

  if layout_needs_refresh then
    refresh_layout(ctx)
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
