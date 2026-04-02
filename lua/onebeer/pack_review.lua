---@module "onebeer.pack_review"
local M = {}

local payload_start = "__ONEBEER_PACK_REVIEW_JSON_START__"
local payload_end = "__ONEBEER_PACK_REVIEW_JSON_END__"
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
    if next_row.status == "Update" then
      next_row.status = "Done"
    end
    updated_rows[i] = next_row
  end
  return updated_rows
end

---@param opts { names?: string[]|nil }
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

  vim.system(cmd, {
    cwd = vim.uv.cwd(),
    env = env,
    text = true,
  }, function(result)
    local payload = extract_payload(result.stdout or "")
    if result.code ~= 0 and payload == nil then
      callback({
        ok = false,
        error = vim.trim(result.stderr ~= "" and result.stderr or result.stdout or "headless discovery failed"),
      })
      return
    end

    if payload == nil or payload == "" then
      callback({ ok = false, error = "headless discovery produced no review payload" })
      return
    end

    local ok, decoded = pcall(vim.json.decode, payload)
    if not ok or type(decoded) ~= "table" then
      callback({ ok = false, error = "failed to decode headless discovery payload" })
      return
    end

    if decoded.ok ~= true then
      callback({ ok = false, error = tostring(decoded.error or "headless discovery failed") })
      return
    end

    local raw_lines = decoded.raw_lines or {}
    callback({
      ok = true,
      raw_lines = raw_lines,
      rows = parse_review_lines(raw_lines),
    })
  end)
end

function M.headless_collect()
  local ok_names, names = pcall(vim.json.decode, vim.env.ONEBEER_PACK_REVIEW_NAMES or "null")
  if not ok_names then
    names = nil
  end
  names = normalize_names(names)

  local ok, err = pcall(vim.pack.update, names)
  if not ok then
    emit_json(vim.json.encode({ ok = false, error = tostring(err) }))
    return
  end

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

  emit_json(vim.json.encode({
    ok = true,
    raw_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
  }))
end

---@param names string[]|nil
function M.open_update(names)
  local review_view = require("onebeer.pack_review_view")
  local scoped_names = normalize_names(names)

  vim.schedule(function()
    local ctx = review_view.open({
      phase = "loading",
      message = scoped_names
          and {
            ("Checking %d %s for updates..."):format(#scoped_names, pluralize(#scoped_names, "plugin", "plugins")),
          }
        or {
          "Checking all managed plugins for updates...",
        },
    })

    M.discover({ names = scoped_names }, function(result)
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
          message = ready_message(rows),
          rows = rows,
          on_apply = function(active_ctx, state)
            local pending = update_names(state.rows or {})
            if pending == nil then
              vim.notify("No pending updates to apply", vim.log.levels.INFO, { title = "Pack review" })
              return
            end

            review_view.update(active_ctx, {
              phase = "applying",
              rows = state.rows,
              message = {
                ("Applying %d %s..."):format(#pending, pluralize(#pending, "update", "updates")),
                "This window will stay open and mark completed plugins as [Done].",
              },
              on_apply = state.on_apply,
              on_cancel = state.on_cancel,
            })
            vim.cmd("redraw")
            vim.defer_fn(function()
              local ok_apply, apply_err = pcall(vim.pack.update, pending, { force = true })
              vim.schedule(function()
                if not ok_apply then
                  review_view.update(active_ctx, {
                    phase = "error",
                    rows = state.rows,
                    message = {
                      "Failed to apply updates.",
                      tostring(apply_err),
                    },
                    on_apply = state.on_apply,
                    on_cancel = state.on_cancel,
                  })
                  return
                end

                review_view.update(active_ctx, {
                  phase = "done",
                  rows = mark_done_rows(state.rows or {}),
                  message = {
                    ("Applied %d %s."):format(#pending, pluralize(#pending, "plugin update", "plugin updates")),
                    "Review the results, then press q to close.",
                  },
                  on_cancel = state.on_cancel,
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
