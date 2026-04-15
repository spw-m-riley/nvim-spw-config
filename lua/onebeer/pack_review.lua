---@module "onebeer.pack_review"
local M = {}

local payload_start = "__ONEBEER_PACK_REVIEW_JSON_START__"
local payload_end = "__ONEBEER_PACK_REVIEW_JSON_END__"
local progress_prefix = "__ONEBEER_PACK_PROGRESS__"
local short_sha_length = 8

---@param names string[]|nil
---@return string[]|nil
local function normalize_names(names)
  if names == nil or names == vim.NIL then
    return nil
  end
  if type(names) ~= "table" or #names == 0 then
    return nil
  end
  return names
end

---@param count integer
---@param singular string
---@param plural string
---@return string
local function pluralize(count, singular, plural)
  return count == 1 and singular or plural
end

---@param lines string[]
local function emit_payload(lines)
  io.write(payload_start .. "\n")
  io.write(table.concat(lines, "\n"))
  io.write("\n" .. payload_end .. "\n")
end

---@param message string
local function emit_json(message)
  emit_payload({ message })
end

---@param event table<string, any>
local function emit_progress(event)
  local ok, encoded = pcall(vim.json.encode, event)
  if not ok then
    return
  end
  io.write(progress_prefix .. encoded .. "\n")
  io.flush()
end

---@param header string
---@return string, boolean
local function parse_plugin_header(header)
  local name = header:gsub("^## ", "")
  local active = not name:find(" %(not active%)$", 1, false)
  name = name:gsub(" %(not active%)$", "")
  return name, active
end

---@param lines string[]
---@return string
local function summarize_details(lines)
  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed:match("^Revision after:") then
      return trimmed:gsub("^Revision after:%s*", "")
    end
  end
  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed:match("^Revision:") then
      return trimmed:gsub("^Revision:%s*", "")
    end
  end
  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed ~= "" and not trimmed:match("^Pending updates:") then
      return trimmed
    end
  end
  return ""
end

---@param text string
---@return string
local function shorten_commit_shas(text)
  return (
    text:gsub("%f[%x](%x%x%x%x%x%x%x%x%x%x%x%x%x*)%f[^%x]", function(sha)
      return sha:sub(1, short_sha_length)
    end)
  )
end

---@param lines string[]
---@return string[]
local function shorten_detail_lines(lines)
  local shortened = {}
  for i, line in ipairs(lines) do
    shortened[i] = shorten_commit_shas(line)
  end
  return shortened
end

---@param lines string[]
---@return onebeer.PackReviewRow[]
local function parse_review_lines(lines)
  local rows = {}
  local current_group = "Update"
  local current = nil

  local function flush_current()
    if current == nil then
      return
    end

    while #current.details > 0 and vim.trim(current.details[1]) == "" do
      table.remove(current.details, 1)
    end
    while #current.details > 0 and vim.trim(current.details[#current.details]) == "" do
      table.remove(current.details, #current.details)
    end

    local details = shorten_detail_lines(current.details)
    local summary = summarize_details(details)
    if not current.active then
      summary = summary ~= "" and ("not active - " .. summary) or "not active"
    end

    rows[#rows + 1] = {
      id = current.name,
      name = current.name,
      status = current.group,
      summary = summary ~= "" and summary or nil,
      details = details,
    }
    current = nil
  end

  for _, line in ipairs(lines) do
    local group = line:match("^# (%S+)")
    if group then
      flush_current()
      current_group = group
    else
      local plugin_header = line:match("^## .+")
      if plugin_header then
        flush_current()
        local name, active = parse_plugin_header(plugin_header)
        current = {
          name = name,
          active = active,
          group = current_group,
          details = {},
        }
      elseif current ~= nil then
        current.details[#current.details + 1] = line
      end
    end
  end

  flush_current()
  return rows
end

---@param lines string[]
---@return integer
local function count_review_plugins(lines)
  local count = 0
  for _, line in ipairs(lines) do
    if line:match("^## ") then
      count = count + 1
    end
  end
  return count
end

---@param stdout string
---@return string|nil
local function extract_payload(stdout)
  local start_at = stdout:find(payload_start, 1, true)
  local end_at = stdout:find(payload_end, 1, true)
  if not start_at or not end_at or end_at <= start_at then
    return nil
  end
  local payload = stdout:sub(start_at + #payload_start, end_at - 1)
  return vim.trim(payload)
end

-- Discovery stdout/progress parsing seam (future streaming lane owns this).
---@return table<string, any>
local function init_discovery_progress_state()
  return {
    stdout_chunks = {},
    stderr_chunks = {},
    stdout_line_buffer = "",
    progress_enabled = true,
  }
end

---@param progress_state table<string, any>
---@param event table
---@param on_progress fun(event: table)|nil
local function dispatch_discovery_progress(progress_state, event, on_progress)
  if progress_state.progress_enabled ~= true or on_progress == nil then
    return
  end
  local ok = pcall(on_progress, event)
  if not ok then
    progress_state.progress_enabled = false
  end
end

---@param progress_state table<string, any>
---@param line string
---@param on_progress fun(event: table)|nil
local function parse_discovery_progress_line(progress_state, line, on_progress)
  if progress_state.progress_enabled ~= true or not vim.startswith(line, progress_prefix) then
    return
  end

  local payload = line:sub(#progress_prefix + 1)
  local ok, event = pcall(vim.json.decode, payload)
  if not ok or type(event) ~= "table" or type(event.message) ~= "string" then
    if progress_state.progress_reset_sent ~= true then
      progress_state.progress_reset_sent = true
      dispatch_discovery_progress(progress_state, { reset = true }, on_progress)
    end
    progress_state.progress_enabled = false
    return
  end

  dispatch_discovery_progress(progress_state, event, on_progress)
end

---@param progress_state table<string, any>
---@param chunk string
---@param on_progress fun(event: table)|nil
local function parse_discovery_stdout_chunk(progress_state, chunk, on_progress)
  if chunk == "" then
    return
  end

  progress_state.stdout_line_buffer = progress_state.stdout_line_buffer .. chunk
  while true do
    local prefix_at = progress_state.stdout_line_buffer:find(progress_prefix, 1, true)
    if prefix_at == nil then
      local keep = math.max(#progress_prefix - 1, 0)
      if #progress_state.stdout_line_buffer > keep then
        progress_state.stdout_line_buffer = progress_state.stdout_line_buffer:sub(-keep)
      end
      break
    end

    local payload_start_at = prefix_at + #progress_prefix
    local newline_at = progress_state.stdout_line_buffer:find("\n", payload_start_at, true)
    if newline_at == nil then
      if prefix_at > 1 then
        progress_state.stdout_line_buffer = progress_state.stdout_line_buffer:sub(prefix_at)
      end
      break
    end

    local line = progress_state.stdout_line_buffer:sub(prefix_at, newline_at - 1)
    progress_state.stdout_line_buffer = progress_state.stdout_line_buffer:sub(newline_at + 1)
    parse_discovery_progress_line(progress_state, line, on_progress)
  end
end

---@param progress_state table<string, any>
---@param chunk string|nil
---@param on_progress fun(event: table)|nil
local function finalize_discovery_stdout(progress_state, chunk, on_progress)
  if type(chunk) == "string" and chunk ~= "" then
    parse_discovery_stdout_chunk(progress_state, chunk, on_progress)
  end

  local line = progress_state.stdout_line_buffer
  if line ~= "" then
    progress_state.stdout_line_buffer = ""
    parse_discovery_progress_line(progress_state, line, on_progress)
  end
end

---@param progress_state table<string, any>
---@param stream "stdout_chunks"|"stderr_chunks"
---@param chunk string|nil
local function append_discovery_chunk(progress_state, stream, chunk)
  if type(chunk) ~= "string" or chunk == "" then
    return
  end
  local chunks = progress_state[stream]
  chunks[#chunks + 1] = chunk
end

---@param progress_state table<string, any>
---@param result vim.SystemCompleted
---@param on_progress fun(event: table)|nil
---@return vim.SystemCompleted
local function finalize_discovery_result(progress_state, result, on_progress)
  if #progress_state.stdout_chunks == 0 then
    append_discovery_chunk(progress_state, "stdout_chunks", result.stdout)
    finalize_discovery_stdout(progress_state, result.stdout, on_progress)
  else
    finalize_discovery_stdout(progress_state, nil, on_progress)
  end
  if #progress_state.stderr_chunks == 0 then
    append_discovery_chunk(progress_state, "stderr_chunks", result.stderr)
  end

  return vim.tbl_extend("force", result, {
    stdout = table.concat(progress_state.stdout_chunks),
    stderr = table.concat(progress_state.stderr_chunks),
  })
end

-- Discovery final-payload decoding seam (future decoder lane owns this).
---@param result vim.SystemCompleted
---@return { ok: boolean, rows?: onebeer.PackReviewRow[], raw_lines?: string[], error?: string }
local function decode_discovery_result(result)
  local payload = extract_payload(result.stdout or "")
  if result.code ~= 0 and payload == nil then
    return {
      ok = false,
      error = vim.trim(result.stderr ~= "" and result.stderr or result.stdout or "headless discovery failed"),
    }
  end

  if payload == nil or payload == "" then
    return { ok = false, error = "headless discovery produced no review payload" }
  end

  local ok, decoded = pcall(vim.json.decode, payload)
  if not ok or type(decoded) ~= "table" then
    return { ok = false, error = "failed to decode headless discovery payload" }
  end

  if decoded.ok ~= true then
    return { ok = false, error = tostring(decoded.error or "headless discovery failed") }
  end

  local raw_lines = decoded.raw_lines or {}
  return {
    ok = true,
    raw_lines = raw_lines,
    rows = parse_review_lines(raw_lines),
  }
end

-- Apply-progress subscription seam (future apply lane owns lifecycle wiring).
local apply_progress_source = "vim.pack"

---@param text any
---@return string|nil
local function normalize_apply_progress_text(text)
  if type(text) == "string" then
    local trimmed = vim.trim(text)
    return trimmed ~= "" and trimmed or nil
  end
  if type(text) ~= "table" then
    return nil
  end

  local parts = {}
  local function collect(value)
    if type(value) == "string" then
      if value ~= "" then
        parts[#parts + 1] = value
      end
      return
    end
    if type(value) ~= "table" then
      return
    end
    for _, item in ipairs(value) do
      collect(item)
    end
  end

  collect(text)
  local joined = vim.trim(table.concat(parts, " "):gsub("[%s\r\n]+", " "))
  return joined ~= "" and joined or nil
end

---@param event table
---@return { percent?: integer, text?: string, active_row_id?: string, status: "running"|"success"|"failed" }|nil
local function normalize_apply_progress_event(event)
  local data = type(event) == "table" and (event.data or event) or {}
  if data.source ~= nil and data.source ~= apply_progress_source then
    return nil
  end

  local text = normalize_apply_progress_text(data.text)
  local active_row_id = text and vim.trim(text:match("%(%d+/%d+%)%s*%-%s*(.+)$") or "") or nil
  if active_row_id == "" then
    active_row_id = nil
  end

  local status = "running"
  if data.status == "success" then
    status = "success"
  elseif data.status ~= nil and data.status ~= "running" then
    status = "failed"
  end

  local percent = type(data.percent) == "number" and math.max(0, math.min(100, math.floor(data.percent))) or nil
  return {
    percent = percent,
    text = text,
    active_row_id = active_row_id,
    status = status,
  }
end

---@param rows onebeer.PackReviewRow[]
---@return onebeer.PackReviewRow[]
local function queue_apply_rows(rows)
  local queued_rows = {}
  for i, row in ipairs(rows) do
    local next_row = vim.tbl_deep_extend("force", {}, row)
    if next_row.status == "Update" then
      next_row.status = "Queued"
    end
    queued_rows[i] = next_row
  end
  return queued_rows
end

---@param pending_count integer
---@param event { percent?: integer, text?: string, active_row_id?: string, status: "running"|"success"|"failed" }
---@return onebeer.PackReviewProgress
local function apply_progress_view_state(pending_count, event)
  local phase_label = "Applying updates"
  if event.status == "success" then
    phase_label = "Apply complete"
  elseif event.status == "failed" then
    phase_label = "Apply failed"
  end

  local current = event.text
  if current == nil and event.active_row_id ~= nil then
    current = ("Applying %s"):format(event.active_row_id)
  end
  if current == nil then
    current = ("Applying %d pending plugins"):format(pending_count)
  end

  return {
    phase_label = phase_label,
    percent = event.percent,
    current = current,
    active_row_id = event.active_row_id,
    indeterminate = event.percent == nil,
    spinner = event.percent == nil,
  }
end

---@param pending_count integer
---@param event { text?: string, status: "running"|"success"|"failed" }
---@return string[]
local function apply_progress_message(pending_count, event)
  if event.status == "failed" then
    return {
      "vim.pack reported a failure while applying updates.",
      event.text or "Review the error output for details.",
    }
  end

  return {
    ("Applying %d %s..."):format(pending_count, pluralize(pending_count, "update", "updates")),
    event.text or "Waiting for vim.pack progress events...",
  }
end

---@param ctx onebeer.PackReviewCtx
---@param handlers { on_progress?: fun(event: { percent?: integer, text?: string, active_row_id?: string, status: "running"|"success"|"failed" }) }|nil
---@return fun()
local function start_apply_progress_subscription(ctx, handlers)
  local group = vim.api.nvim_create_augroup(("onebeer.pack_review.apply.%d.%d"):format(ctx.buf, vim.uv.hrtime()), {
    clear = true,
  })
  local stopped = false

  local function stop()
    if stopped then
      return
    end
    stopped = true
    pcall(vim.api.nvim_del_augroup_by_id, group)
  end

  vim.api.nvim_create_autocmd("Progress", {
    group = group,
    pattern = apply_progress_source,
    callback = function(ev)
      if stopped then
        return
      end
      if not (ctx and vim.api.nvim_buf_is_valid(ctx.buf)) then
        stop()
        return
      end

      local progress_event = normalize_apply_progress_event(ev)
      if progress_event == nil then
        return
      end
      if handlers and type(handlers.on_progress) == "function" then
        handlers.on_progress(progress_event)
      end
      if progress_event.status ~= "running" then
        stop()
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = ctx.buf,
    callback = stop,
  })

  return stop
end

-- Apply row-state seam (future row-progress lane owns mutations).
---@param rows onebeer.PackReviewRow[]
---@param event { active_row_id?: string, status: "running"|"success"|"failed" }
---@return onebeer.PackReviewRow[]
local function update_rows_from_progress_event(rows, event)
  local updated_rows = {}
  local active_row_id = event.active_row_id

  for i, row in ipairs(rows) do
    local next_row = vim.tbl_deep_extend("force", {}, row)
    local is_active = active_row_id ~= nil and (next_row.id == active_row_id or next_row.name == active_row_id)

    if event.status == "success" then
      if next_row.status == "Update" or next_row.status == "Queued" or next_row.status == "Applying" then
        next_row.status = "Done"
      end
    elseif event.status == "failed" then
      if is_active or next_row.status == "Applying" then
        next_row.status = "Error"
      elseif next_row.status == "Update" then
        next_row.status = "Queued"
      end
    else
      if next_row.status == "Update" then
        next_row.status = "Queued"
      end
      if active_row_id ~= nil then
        if is_active then
          next_row.status = "Applying"
        elseif next_row.status == "Applying" then
          next_row.status = "Done"
        end
      end
    end

    updated_rows[i] = next_row
  end

  return updated_rows
end

---@param names string[]|nil
local function stock_fallback(names)
  vim.notify("Falling back to stock vim.pack.update()", vim.log.levels.WARN, { title = "Pack review" })
  vim.pack.update(names)
end

---@param rows onebeer.PackReviewRow[]
---@return string[]
local function ready_message(rows)
  local update_count = 0
  local error_count = 0
  for _, row in ipairs(rows) do
    if row.status == "Update" then
      update_count = update_count + 1
    elseif row.status == "Error" then
      error_count = error_count + 1
    end
  end

  local message = {
    ("Checked %d %s."):format(#rows, pluralize(#rows, "plugin", "plugins")),
    ("%d %s available."):format(update_count, pluralize(update_count, "update", "updates")),
  }
  if error_count > 0 then
    message[#message + 1] = ("%d %s reported errors."):format(error_count, pluralize(error_count, "plugin", "plugins"))
  end
  return message
end

---@param rows onebeer.PackReviewRow[]
---@return string[]|nil
local function update_names(rows)
  local names = {}
  for _, row in ipairs(rows) do
    if row.status == "Update" then
      names[#names + 1] = row.name
    end
  end
  return normalize_names(names)
end

---@param rows onebeer.PackReviewRow[]
---@return onebeer.PackReviewRow[]
local function mark_done_rows(rows)
  local updated_rows = {}
  for i, row in ipairs(rows) do
    local next_row = vim.tbl_deep_extend("force", {}, row)
    if next_row.status == "Update" or next_row.status == "Queued" or next_row.status == "Applying" then
      next_row.status = "Done"
    end
    updated_rows[i] = next_row
  end
  return updated_rows
end

---@param rows onebeer.PackReviewRow[]
---@param status onebeer.PackReviewStatus
---@return integer
local function count_rows_with_status(rows, status)
  local count = 0
  for _, row in ipairs(rows) do
    if row.status == status then
      count = count + 1
    end
  end
  return count
end

---@param opts { names?: string[]|nil, on_progress?: fun(event: table)|nil }
---@param callback fun(result: { ok: boolean, rows?: onebeer.PackReviewRow[], raw_lines?: string[], error?: string })
function M.discover(opts, callback)
  local config_path = vim.fn.stdpath("config")
  local config_home = vim.fs.dirname(config_path)
  local appname = vim.fs.basename(config_path)
  local names = normalize_names(opts and opts.names or nil)
  local env = vim.tbl_extend("force", vim.fn.environ(), {
    XDG_CONFIG_HOME = config_home,
    NVIM_APPNAME = appname,
    ONEBEER_PACK_REVIEW_NAMES = vim.json.encode(names),
  })

  local cmd = {
    vim.v.progpath,
    "--headless",
    "+lua require('onebeer.pack_review').headless_collect()",
    "+qa",
  }

  local progress_state = init_discovery_progress_state()
  vim.system(cmd, {
    cwd = vim.uv.cwd(),
    env = env,
    text = true,
    stdout = function(_, data)
      append_discovery_chunk(progress_state, "stdout_chunks", data)
      parse_discovery_stdout_chunk(progress_state, data or "", opts and opts.on_progress or nil)
    end,
    stderr = function(_, data)
      append_discovery_chunk(progress_state, "stderr_chunks", data)
    end,
  }, function(result)
    callback(
      decode_discovery_result(finalize_discovery_result(progress_state, result, opts and opts.on_progress or nil))
    )
  end)
end

function M.headless_collect()
  local ok_names, names = pcall(vim.json.decode, vim.env.ONEBEER_PACK_REVIEW_NAMES or "null")
  if not ok_names then
    names = nil
  end
  names = normalize_names(names)

  emit_progress({
    stage = "start",
    message = names and ("Checking %d targeted %s"):format(#names, pluralize(#names, "plugin", "plugins"))
      or "Checking all managed plugins",
  })
  emit_progress({
    stage = "request-review",
    message = "Requesting review data from vim.pack.update()",
  })
  local ok, err = pcall(vim.pack.update, names)
  if not ok then
    emit_json(vim.json.encode({ ok = false, error = tostring(err) }))
    return
  end

  emit_progress({
    stage = "collect-review-buffer",
    message = "Collecting generated review buffer",
  })
  local bufnr = nil
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match("^nvim%-pack://confirm#") then
      bufnr = buf
      break
    end
  end

  if bufnr == nil then
    emit_json(vim.json.encode({ ok = false, error = "vim.pack did not create a review buffer" }))
    return
  end

  local raw_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local plugin_count = count_review_plugins(raw_lines)
  emit_progress({
    stage = "payload-ready",
    message = ("Prepared review for %d %s"):format(plugin_count, pluralize(plugin_count, "plugin", "plugins")),
    plugin_count = plugin_count,
  })
  emit_json(vim.json.encode({
    ok = true,
    raw_lines = raw_lines,
  }))
end

---@param names string[]|nil
function M.open_update(names)
  local review_view = require("onebeer.pack_review_view")
  local scoped_names = normalize_names(names)

  vim.schedule(function()
    local loading_current = scoped_names and ("Checking %d targeted plugins"):format(#scoped_names)
      or "Checking all managed plugins"
    local loading_message = scoped_names
        and {
          ("Checking %d %s for updates..."):format(#scoped_names, pluralize(#scoped_names, "plugin", "plugins")),
        }
      or {
        "Checking all managed plugins for updates...",
      }
    local ctx = review_view.open({
      phase = "loading",
      progress = {
        phase_label = "Discovering updates",
        current = loading_current,
        indeterminate = true,
        spinner = true,
      },
      message = loading_message,
    })

    M.discover({
      names = scoped_names,
      on_progress = function(event)
        if type(event) ~= "table" then
          return
        end

        vim.schedule(function()
          review_view.update(ctx, {
            phase = "loading",
            progress = {
              phase_label = "Discovering updates",
              current = event.reset and loading_current or event.message,
              indeterminate = true,
              spinner = true,
            },
            message = event.reset and loading_message or { event.message },
          })
        end)
      end,
    }, function(result)
      vim.schedule(function()
        if result.ok ~= true then
          review_view.close(ctx)
          vim.notify(
            ("Pack review discovery failed: %s"):format(result.error or "unknown error"),
            vim.log.levels.WARN,
            { title = "Pack review" }
          )
          stock_fallback(scoped_names)
          return
        end

        local rows = result.rows or {}
        review_view.update(ctx, {
          phase = "ready",
          progress = {
            phase_label = "Review ready",
            percent = 100,
            current = ("%d %s ready for review"):format(#rows, pluralize(#rows, "plugin", "plugins")),
          },
          message = ready_message(rows),
          rows = rows,
          on_apply = function(active_ctx, state)
            local pending = update_names(state.rows or {})
            if pending == nil then
              vim.notify("No pending updates to apply", vim.log.levels.INFO, { title = "Pack review" })
              return
            end

            local function cleanup() end
            local function handle_cancel(cancel_ctx, cancel_state)
              cleanup()
              if type(state.on_cancel) == "function" then
                state.on_cancel(cancel_ctx, cancel_state)
              end
            end

            local stop_apply_progress = start_apply_progress_subscription(active_ctx, {
              on_progress = function(progress_event)
                review_view.update(active_ctx, {
                  phase = "applying",
                  progress = apply_progress_view_state(#pending, progress_event),
                  rows = update_rows_from_progress_event(active_ctx.state.rows or {}, progress_event),
                  message = apply_progress_message(#pending, progress_event),
                  on_cancel = handle_cancel,
                })
              end,
            })
            cleanup = function()
              stop_apply_progress()
            end
            review_view.update(active_ctx, {
              phase = "applying",
              progress = apply_progress_view_state(#pending, {
                status = "running",
                text = ("Queued %d pending plugins"):format(#pending),
              }),
              rows = queue_apply_rows(active_ctx.state.rows or {}),
              message = {
                ("Applying %d %s..."):format(#pending, pluralize(#pending, "update", "updates")),
                "Queued pending plugins and waiting for vim.pack progress...",
              },
              on_cancel = handle_cancel,
            })
            vim.cmd("redraw")
            vim.defer_fn(function()
              local ok_apply, apply_err = pcall(vim.pack.update, pending, { force = true })
              vim.schedule(function()
                if not ok_apply then
                  cleanup()
                  review_view.update(active_ctx, {
                    phase = "error",
                    progress = {
                      phase_label = "Apply failed",
                      current = "vim.pack.update() reported an error",
                      indeterminate = true,
                    },
                    rows = active_ctx.state.rows,
                    message = {
                      "Failed to apply updates.",
                      tostring(apply_err),
                    },
                    on_cancel = handle_cancel,
                  })
                  return
                end

                cleanup()
                local final_rows = mark_done_rows(active_ctx.state.rows or {})
                local error_count = count_rows_with_status(final_rows, "Error")
                local applied_count = count_rows_with_status(final_rows, "Done")
                review_view.update(active_ctx, {
                  phase = error_count > 0 and "error" or "done",
                  progress = {
                    phase_label = error_count > 0 and "Apply finished with errors" or "Apply complete",
                    percent = 100,
                    current = error_count > 0 and ("%d applied, %d failed"):format(applied_count, error_count)
                      or ("%d %s applied"):format(#pending, pluralize(#pending, "plugin", "plugins")),
                  },
                  rows = final_rows,
                  message = error_count > 0
                      and {
                        ("Applied %d %s; %d %s failed."):format(
                          applied_count,
                          pluralize(applied_count, "plugin update", "plugin updates"),
                          error_count,
                          pluralize(error_count, "plugin", "plugins")
                        ),
                        "Review the error rows, then press q to close.",
                      }
                    or {
                      ("Applied %d %s."):format(#pending, pluralize(#pending, "plugin update", "plugin updates")),
                      "Review the results, then press q to close.",
                    },
                  on_cancel = handle_cancel,
                })
              end)
            end, 10)
          end,
          on_cancel = function()
            vim.notify("Pack review cancelled", vim.log.levels.INFO, { title = "Pack review" })
          end,
        })
      end)
    end)
  end)
end

return M
