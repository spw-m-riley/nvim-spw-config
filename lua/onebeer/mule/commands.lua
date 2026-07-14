---@class onebeer.mule.Commands
local M = {}

local create_command = require("onebeer.autocmds.helpers").create_command

local title = "Mule"

---@param ctx vim.api.keyset.user_command.callback_args
---@return string[]
local function command_args(ctx)
  return ctx.fargs or {}
end

---@param value string|nil
---@return boolean
local function is_json_output(value)
  return type(value) == "string" and value:lower() == "json"
end

---@param args string[]
---@return boolean
local function wants_json(args)
  local index = 1
  while index <= #args do
    local arg = args[index]
    local long_value = arg:match("^%-%-output=(.+)$")
    if is_json_output(long_value) then
      return true
    end

    local short_value = arg:match("^%-o=(.+)$")
    if is_json_output(short_value) then
      return true
    end

    if arg == "--output" or arg == "-o" then
      if is_json_output(args[index + 1]) then
        return true
      end
      index = index + 2
    else
      index = index + 1
    end
  end

  return false
end

---@param ctx vim.api.keyset.user_command.callback_args
local function build(ctx)
  local args = command_args(ctx)
  local ok, result = require("onebeer.mule.jobs.maven").build({
    args = #args > 0 and args or nil,
    quickfix = true,
  })

  if ok then
    vim.notify("Maven build complete", vim.log.levels.INFO, { title = title })
    return
  end

  if type(result) == "string" then
    vim.notify(result, vim.log.levels.WARN, { title = title })
    return
  end

  vim.notify("Maven build failed; see quickfix for details", vim.log.levels.ERROR, { title = title })
end

---@param ctx vim.api.keyset.user_command.callback_args
local function test(ctx)
  local selector = vim.trim(ctx.args)
  local ok, result = require("onebeer.mule.jobs.munit").run({
    quickfix = true,
    selector = selector ~= "" and selector or nil,
  })

  if ok then
    vim.notify("MUnit run complete", vim.log.levels.INFO, { title = title })
    return
  end

  if type(result) == "string" then
    vim.notify(result, vim.log.levels.WARN, { title = title })
    return
  end

  vim.notify("MUnit run failed; see quickfix for details", vim.log.levels.ERROR, { title = title })
end

local function test_nearest()
  local path = vim.api.nvim_buf_get_name(0)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local nearest = require("onebeer.mule.jobs.munit").nearest(path, cursor[1])
  if nearest == nil then
    vim.notify("No nearest MUnit test found", vim.log.levels.WARN, { title = title })
    return
  end

  local selector = require("onebeer.mule.jobs.munit").selector(nearest)
  local ok, result = require("onebeer.mule.jobs.munit").run({
    path = path,
    quickfix = true,
    selector = selector,
  })

  if ok then
    vim.notify(("MUnit test complete: %s"):format(selector), vim.log.levels.INFO, { title = title })
    return
  end

  if type(result) == "string" then
    vim.notify(result, vim.log.levels.WARN, { title = title })
    return
  end

  vim.notify(("MUnit test failed: %s"):format(selector), vim.log.levels.ERROR, { title = title })
end

---@param value any
---@return string|nil, string|nil
local function render_output(value)
  if value == nil or value == "" then
    return "(no output)", nil
  end
  if value == vim.NIL then
    return "null", nil
  end
  if type(value) == "string" then
    return value, nil
  end
  if type(value) == "number" or type(value) == "boolean" then
    return tostring(value), nil
  end
  if type(value) == "table" then
    return vim.inspect(value), nil
  end
  return nil, ("Unsupported Mule command output type: %s"):format(type(value))
end

---@param title_text string
---@param output string
local function open_output(title_text, output)
  local lines = vim.split(output, "\n", { plain = true })
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "dataweave-output"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_open_win(buf, true, {
    border = "rounded",
    height = math.min(#lines + 2, math.max(3, vim.o.lines - 4)),
    relative = "editor",
    row = 2,
    col = 4,
    style = "minimal",
    title = title_text,
    width = math.min(100, math.max(40, vim.o.columns - 8)),
  })
end

local function dw_validate()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("Write the buffer before validating DataWeave", vim.log.levels.WARN, { title = title })
    return
  end

  local ok, result = require("onebeer.mule.jobs.dataweave").validate_file(path)
  if ok then
    vim.notify("DataWeave validation complete", vim.log.levels.INFO, { title = title })
    return
  end

  if type(result) == "string" then
    vim.notify(result, vim.log.levels.WARN, { title = title })
    return
  end

  vim.notify("DataWeave validation failed; see quickfix for details", vim.log.levels.ERROR, { title = title })
end

local function dw_run()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("Write the buffer before running DataWeave", vim.log.levels.WARN, { title = title })
    return
  end

  local ok, result = require("onebeer.mule.jobs.dataweave").run_file(path)
  if ok then
    local output, err = render_output(result.stdout)
    if output == nil then
      vim.notify(err, vim.log.levels.ERROR, { title = title })
      return
    end
    open_output("DataWeave Output", output)
    return
  end

  if type(result) == "string" then
    vim.notify(result, vim.log.levels.WARN, { title = title })
    return
  end

  vim.notify("DataWeave run failed; see quickfix for details", vim.log.levels.ERROR, { title = title })
end

local function dw_repl()
  local executable = require("onebeer.mule.config").executable("dw")
  if executable == nil then
    vim.notify("Missing DataWeave executable config", vim.log.levels.WARN, { title = title })
    return
  end

  local cmd
  if type(executable) == "table" then
    cmd = vim.deepcopy(executable)
    table.insert(cmd, "repl")
  else
    cmd = { executable, "repl" }
  end

  vim.cmd("botright split")
  vim.fn.termopen(cmd)
  vim.cmd("startinsert")
end

local function generate_catalog()
  local detect = require("onebeer.mule.detect")
  local catalog = require("onebeer.mule.catalog")
  local project = detect.project(vim.api.nvim_buf_get_name(0))
  if project == nil then
    vim.notify("No Mule project detected", vim.log.levels.WARN, { title = title })
    return
  end

  local output, err = catalog.generate(vim.api.nvim_buf_get_name(0), nil)
  if output == nil then
    local level = vim.log.levels.ERROR
    if err ~= nil and err:find("No Mule XML schema mappings found", 1, true) ~= nil then
      level = vim.log.levels.WARN
    end
    vim.notify(err or "Failed to generate Mule XML catalog", level, { title = title })
    return
  end

  local refreshed, refresh_err =
    pcall(require("onebeer.mule.integrations.lemminx").refresh, vim.api.nvim_buf_get_name(0))
  if not refreshed then
    vim.notify(
      ("Mule XML catalog written to %s, but LemMinX refresh failed: %s"):format(output, refresh_err),
      vim.log.levels.ERROR,
      { title = title }
    )
    return
  end

  vim.notify(("Mule XML catalog written to %s"):format(output), vim.log.levels.INFO, { title = title })
end

local function api_navigate()
  local path = vim.api.nvim_buf_get_name(0)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local apikit = require("onebeer.mule.api.apikit")
  local flow = apikit.generated_flow_at(path, cursor[1])
  if flow == nil then
    vim.notify("Place the cursor on an APIKit generated <flow> declaration", vim.log.levels.WARN, { title = title })
    return
  end

  local target, err = apikit.route_for_flow(path, flow.name)
  if target == nil then
    vim.notify(err or "APIKit route could not be resolved", vim.log.levels.WARN, { title = title })
    return
  end

  vim.cmd.edit(vim.fn.fnameescape(target.spec_path))
  vim.api.nvim_win_set_cursor(0, { target.line, 0 })
end

local function anypoint_status(ctx)
  local args = command_args(ctx)
  if #args == 0 then
    vim.notify("Usage: :MuleStatus <anypoint-cli-v4 args>", vim.log.levels.WARN, { title = title })
    return
  end

  local ok, result = require("onebeer.mule.jobs.anypoint").run(args, { json = wants_json(args) })
  if ok then
    local output, err = render_output(result)
    if output == nil then
      vim.notify(err, vim.log.levels.ERROR, { title = title })
      return
    end
    vim.notify("Anypoint command complete", vim.log.levels.INFO, { title = title })
    open_output("Anypoint Output", output)
    return
  end

  vim.notify(result.message, result.kind == "auth" and vim.log.levels.ERROR or vim.log.levels.WARN, { title = title })
end

---@return nil
function M.setup()
  create_command("MuleBuild", build, {
    desc = "Run Maven package/build for the current Mule project",
    nargs = "*",
  })
  create_command("MuleTest", test, {
    desc = "Run MUnit tests for the current Mule project",
    nargs = "?",
  })
  create_command("MuleTestNearest", test_nearest, {
    desc = "Run nearest MUnit test",
  })
  create_command("MuleDwValidate", dw_validate, {
    desc = "Validate current DataWeave buffer with dw",
  })
  create_command("MuleDwRun", dw_run, {
    desc = "Run current DataWeave buffer with dw",
  })
  create_command("MuleDwRepl", dw_repl, {
    desc = "Open DataWeave CLI REPL",
  })
  create_command("MuleGenerateCatalog", generate_catalog, {
    desc = "Generate Mule XML catalog for LemMinX",
  })
  create_command("MuleApiNavigate", api_navigate, {
    desc = "Navigate APIKit generated flow to its local API route",
  })
  create_command("MuleStatus", anypoint_status, {
    desc = "Run explicit Anypoint CLI status/list command",
    nargs = "*",
  })
end

return M
