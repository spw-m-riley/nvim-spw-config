---@class onebeer.mule.Smoke
local M = {}

local config = require("onebeer.mule.config")

---@param value any
---@return string
local function inspect(value)
  return vim.inspect(value, { newline = " ", indent = "" })
end

---@param label string
---@param actual any
---@param expected any
local function assert_equal(label, actual, expected)
  if not vim.deep_equal(actual, expected) then
    error(("%s: expected %s, got %s"):format(label, inspect(expected), inspect(actual)), 0)
  end
end

---@param label string
---@param condition boolean
---@param message string
local function assert_true(label, condition, message)
  if not condition then
    error(("%s: %s"):format(label, message), 0)
  end
end

---@param executable string|string[]
---@return string[]
local function as_cmd(executable)
  if type(executable) == "table" then
    return executable
  end
  return { executable }
end

---@param name string
---@return vim.SystemCompleted
local function run_executable(name)
  local executable = config.executable(name)
  assert_true("configured executable", executable ~= nil, ("missing executable %s"):format(name))

  local ok, system_obj = pcall(vim.system, as_cmd(executable), { text = true })
  if not ok then
    error(("run %s: %s"):format(name, system_obj), 0)
  end

  return system_obj:wait()
end

local function harness()
  assert_true("fixture root", vim.fn.isdirectory(config.fixture_root()) == 1, "fixture root does not exist")
  assert_true("fixture bin root", vim.fn.isdirectory(config.fixture_bin_root()) == 1, "fixture bin root does not exist")

  local ok_result = run_executable("harness_ok")
  assert_equal("harness ok exit", ok_result.code, 0)
  assert_equal("harness ok stdout", vim.trim(ok_result.stdout or ""), "onebeer-mule-smoke-ok")

  local fail_result = run_executable("harness_fail")
  assert_equal("harness fail exit", fail_result.code, 42)
  assert_equal("harness fail stderr", vim.trim(fail_result.stderr or ""), "onebeer-mule-smoke-fail")

  local overridden = config.with({
    executables = {
      harness_ok = config.executable("harness_fail"),
    },
  }, function()
    return run_executable("harness_ok")
  end)
  assert_equal("config-injected executable exit", overridden.code, 42)
end

---@param path string
---@return string
local function fixture_path(path)
  return config.fixture_root() .. "/" .. path
end

---@param mule_root string
---@param reports table[]
---@param fn fun(paths: string[])
local function with_surefire_reports(mule_root, reports, fn)
  local target_root = mule_root .. "/target"
  local report_dir = target_root .. "/surefire-reports"
  vim.fn.delete(target_root, "rf")
  assert_true("Surefire report dir", vim.fn.mkdir(report_dir, "p") ~= 0, "failed to create report directory")

  local paths = {}
  for _, report in ipairs(reports) do
    local target = report_dir .. "/" .. report.name
    local ok, lines = pcall(vim.fn.readfile, fixture_path(report.fixture))
    assert_true("Surefire fixture read", ok, ("failed to read %s"):format(report.fixture))
    assert_true("Surefire fixture write", vim.fn.writefile(lines, target) == 0, ("failed to write %s"):format(target))
    paths[#paths + 1] = target
  end

  local ok, result = pcall(fn, paths)
  vim.fn.delete(target_root, "rf")
  if not ok then
    error(result, 0)
  end
end

---@param fn fun()
---@return table[]
---@return any
local function with_notifications(fn)
  local notifications = {}
  local original_notify = vim.notify
  vim.notify = function(message, level, opts)
    notifications[#notifications + 1] = {
      level = level,
      message = tostring(message),
      title = opts and opts.title or nil,
    }
  end

  local ok, result = pcall(fn)
  vim.notify = original_notify
  if not ok then
    error(result, 0)
  end
  return notifications, result
end

---@param path string
---@param fn fun(bufnr: integer)
---@return any
local function with_fixture_buffer(path, fn)
  local previous_win = vim.api.nvim_get_current_win()
  local previous_buf = vim.api.nvim_get_current_buf()
  local existing_buf = vim.fn.bufnr(path)
  local created = existing_buf == -1
  local scratch_buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_win_set_buf(previous_win, scratch_buf)
  vim.cmd.edit(vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()

  local ok, result = pcall(fn, buf)

  if vim.api.nvim_win_is_valid(previous_win) and vim.api.nvim_buf_is_valid(previous_buf) then
    pcall(vim.api.nvim_win_set_buf, previous_win, previous_buf)
  end
  if created and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
  if vim.api.nvim_buf_is_valid(scratch_buf) then
    pcall(vim.api.nvim_buf_delete, scratch_buf, { force = true })
  end

  if not ok then
    error(result, 0)
  end
  return result
end

---@param fn fun()
---@return table[]
---@return any
local function with_output_windows(fn)
  local existing = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    existing[win] = true
  end

  local ok, result = pcall(fn)

  local outputs = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if not existing[win] then
      local buf = vim.api.nvim_win_get_buf(win)
      outputs[#outputs + 1] = {
        lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false),
        win = win,
      }
    end
  end
  for _, output in ipairs(outputs) do
    pcall(vim.api.nvim_win_close, output.win, true)
  end

  if not ok then
    error(result, 0)
  end

  return outputs, result
end

---@param notifications table[]
---@param text string
---@return table|nil
local function find_notification(notifications, text)
  for _, notification in ipairs(notifications) do
    if notification.message:find(text, 1, true) ~= nil then
      return notification
    end
  end
  return nil
end

---@param root string
local function cleanup_project_artifacts(root)
  vim.fn.delete(root .. "/target", "rf")
  vim.fn.delete(root .. "/.onebeer", "rf")
end

local function cleanup_fixture_buffers()
  local root = config.fixture_root() .. "/"
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_current_buf() ~= buf then
      local name = vim.api.nvim_buf_get_name(buf)
      if vim.startswith(name, root) then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end
end

local mule_command_names = {
  "MuleBuild",
  "MuleTest",
  "MuleTestNearest",
  "MuleDwValidate",
  "MuleDwRun",
  "MuleDwRepl",
  "MuleGenerateCatalog",
  "MuleStatus",
}

local function setup_mule_commands()
  for _, name in ipairs(mule_command_names) do
    pcall(vim.api.nvim_del_user_command, name)
  end
  require("onebeer.mule.commands").setup()
end

---@param command string
---@return table[]
local function run_command(command)
  local notifications = with_notifications(function()
    vim.cmd(command)
  end)
  return notifications
end

local function commands()
  local mule_root = fixture_path("projects/basic-mule")
  local main_xml = mule_root .. "/src/main/mule/api.xml"
  local munit_xml = mule_root .. "/src/test/munit/api-test.xml"
  local dwl = mule_root .. "/src/main/resources/dw/hello.dwl"
  local not_mule_xml = fixture_path("projects/not-mule/random.xml")
  local catalog_path = mule_root .. "/.onebeer/mule-catalog.xml"
  local no_xsd_root = fixture_path("scratch/commands-no-xsd")
  local no_xsd_xml = no_xsd_root .. "/src/main/mule/api.xml"
  local no_xsd_catalog = no_xsd_root .. "/.onebeer/mule-catalog.xml"
  local command_scratch = fixture_path("scratch/commands")
  local captured_args_path = command_scratch .. "/maven-args.txt"
  local capture_maven = command_scratch .. "/mvn-capture"
  local catalog_blocker = command_scratch .. "/catalog-blocker"
  local blocked_catalog = catalog_blocker .. "/catalog.xml"

  cleanup_project_artifacts(mule_root)
  vim.fn.delete(no_xsd_root, "rf")
  vim.fn.delete(command_scratch, "rf")
  assert_true(
    "commands scratch parent mkdir",
    vim.fn.mkdir(vim.fn.fnamemodify(no_xsd_root, ":h"), "p") ~= 0,
    "failed to create commands scratch parent"
  )
  assert_true("commands scratch mkdir", vim.fn.mkdir(command_scratch, "p") ~= 0, "failed to create commands scratch")
  assert_true(
    "commands catalog blocker",
    vim.fn.writefile({ "blocker" }, catalog_blocker) == 0,
    "failed to create catalog blocker"
  )
  assert_true("commands capture script write", vim.fn.writefile({
    "#!/bin/sh",
    ("capture_path='%s'"):format(captured_args_path),
    ': > "$capture_path"',
    'for arg in "$@"; do',
    '  printf \'%s\\n\' "$arg" >> "$capture_path"',
    "done",
    "printf '%s\\n' 'maven ok'",
  }, capture_maven) == 0, "failed to write capture script")
  assert_true("commands capture script perms", vim.fn.setfperm(capture_maven, "rwxr-xr-x") == 1, "failed to chmod")
  local copy_result = vim.fn.system({ "cp", "-R", mule_root, no_xsd_root })
  assert_equal("commands no-xsd fixture copy status", vim.v.shell_error, 0)
  assert_true("commands no-xsd fixture copy output", type(copy_result) == "string", "missing copy output")
  for _, path in ipairs(vim.fn.glob(no_xsd_root .. "/src/main/resources/**/*.xsd", false, true)) do
    vim.fn.delete(path)
  end
  for _, path in ipairs(vim.fn.glob(no_xsd_root .. "/exchange_modules/**/*.xsd", false, true)) do
    vim.fn.delete(path)
  end

  local ok, result = pcall(function()
    config.with({
      executables = {
        anypoint = config.fixture_bin_root() .. "/anypoint-ok",
        dw = config.fixture_bin_root() .. "/dw-ok",
        maven = capture_maven,
      },
    }, function()
      setup_mule_commands()

      with_fixture_buffer(main_xml, function()
        local notifications = run_command("MuleBuild")
        local completed = find_notification(notifications, "Maven build complete")
        assert_true("MuleBuild notification", completed ~= nil, "missing success notification")
        assert_equal("MuleBuild level", completed.level, vim.log.levels.INFO)
      end)

      with_fixture_buffer(main_xml, function()
        vim.fn.delete(captured_args_path)
        local notifications = run_command("MuleBuild -DskipTests -Dexample=value\\ with\\ spaces")

        local completed = find_notification(notifications, "Maven build complete")
        assert_true("MuleBuild quoted args notification", completed ~= nil, "missing success notification")
        local captured_args = vim.fn.readfile(captured_args_path)
        assert_equal("MuleBuild quoted args count", #captured_args, 2)
        assert_equal("MuleBuild quoted arg[1]", captured_args[1], "-DskipTests")
        assert_equal("MuleBuild quoted arg[2]", captured_args[2], "-Dexample=value with spaces")
      end)

      with_fixture_buffer(munit_xml, function()
        local notifications = run_command("MuleTest")
        local completed = find_notification(notifications, "MUnit run complete")
        assert_true("MuleTest notification", completed ~= nil, "missing success notification")
        assert_equal("MuleTest level", completed.level, vim.log.levels.INFO)
      end)

      with_fixture_buffer(munit_xml, function()
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        local notifications = run_command("MuleTestNearest")
        local completed = find_notification(notifications, "MUnit test complete: api-test#api-main-test")
        assert_true("MuleTestNearest selector", completed ~= nil, "missing nearest-selector notification")
        assert_equal("MuleTestNearest level", completed.level, vim.log.levels.INFO)
      end)

      with_fixture_buffer(dwl, function()
        local notifications = run_command("MuleDwValidate")
        local validated = find_notification(notifications, "DataWeave validation complete")
        assert_true("MuleDwValidate notification", validated ~= nil, "missing validate notification")
        assert_equal("MuleDwValidate level", validated.level, vim.log.levels.INFO)

        local outputs, run_notifications = with_output_windows(function()
          return run_command("MuleDwRun")
        end)
        assert_true("MuleDwRun output window", #outputs > 0, "expected output window")
        assert_true(
          "MuleDwRun output content",
          table.concat(outputs[1].lines, "\n"):find("dw run ok:", 1, true) ~= nil,
          "missing DataWeave output"
        )
        assert_equal("MuleDwRun notifications", #run_notifications, 0)
      end)

      with_fixture_buffer(main_xml, function()
        local notifications = run_command("MuleGenerateCatalog")
        local generated = find_notification(notifications, "Mule XML catalog written to")
        assert_true("MuleGenerateCatalog success notification", generated ~= nil, "missing catalog notification")
        assert_equal("MuleGenerateCatalog success level", generated.level, vim.log.levels.INFO)
        assert_true("MuleGenerateCatalog wrote file", vim.uv.fs_stat(catalog_path) ~= nil, "missing catalog output")
        local catalog_content = table.concat(vim.fn.readfile(catalog_path), "\n")
        assert_true("MuleGenerateCatalog non-empty", catalog_content:find("<uri ", 1, true) ~= nil, "missing uri row")
      end)

      local catalog = require("onebeer.mule.catalog")
      local original_generate = catalog.generate
      catalog.generate = function(startpath, mappings, _, opts)
        return original_generate(startpath, mappings, blocked_catalog, opts)
      end
      local generated_ok, generated_err = pcall(function()
        with_fixture_buffer(main_xml, function()
          local notifications = run_command("MuleGenerateCatalog")
          local failed = find_notification(notifications, blocked_catalog)
          assert_true("MuleGenerateCatalog blocked notification", failed ~= nil, "missing blocked catalog notification")
          assert_equal("MuleGenerateCatalog blocked level", failed.level, vim.log.levels.ERROR)
          assert_equal("MuleGenerateCatalog blocked output", vim.uv.fs_stat(blocked_catalog), nil)
        end)
      end)
      catalog.generate = original_generate
      if not generated_ok then
        error(generated_err, 0)
      end

      with_fixture_buffer(no_xsd_xml, function()
        local notifications = run_command("MuleGenerateCatalog")
        local warned = find_notification(notifications, "No Mule XML schema mappings found")
        assert_true("MuleGenerateCatalog empty warning", warned ~= nil, "missing empty-mapping warning")
        assert_equal("MuleGenerateCatalog empty warning level", warned.level, vim.log.levels.WARN)
        assert_equal("MuleGenerateCatalog empty output", vim.uv.fs_stat(no_xsd_catalog), nil)
      end)

      with_fixture_buffer(main_xml, function()
        local outputs, notifications = with_output_windows(function()
          return run_command("MuleStatus runtime-mgr:application:describe demo --output=json")
        end)
        local completed = find_notification(notifications, "Anypoint command complete")
        assert_true("MuleStatus notification", completed ~= nil, "missing status notification")
        assert_equal("MuleStatus level", completed.level, vim.log.levels.INFO)
        assert_true("MuleStatus output window", #outputs > 0, "expected output window")
        local output = table.concat(outputs[1].lines, "\n")
        assert_true(
          "MuleStatus output is inspected table",
          output:find('status = "STARTED"', 1, true) ~= nil,
          "expected inspected table output"
        )
        assert_true(
          "MuleStatus output contains status",
          output:find("STARTED", 1, true) ~= nil,
          "missing STARTED output"
        )
        assert_true(
          "MuleStatus output is not raw JSON string",
          output:find('{"status":"STARTED"}', 1, true) == nil,
          "unexpected raw JSON output"
        )
      end)

      for _, case in ipairs({
        { args = "fixture-null", output = "null" },
        { args = "fixture-boolean", output = "true" },
        { args = "fixture-number", output = "42" },
      }) do
        with_fixture_buffer(main_xml, function()
          local outputs, notifications = with_output_windows(function()
            return run_command(("MuleStatus %s --output=json"):format(case.args))
          end)
          local completed = find_notification(notifications, "Anypoint command complete")
          assert_true("MuleStatus scalar notification", completed ~= nil, "missing scalar status notification")
          assert_true("MuleStatus scalar output window", #outputs > 0, "expected scalar output window")
          assert_equal("MuleStatus scalar output", table.concat(outputs[1].lines, "\n"), case.output)
        end)
      end

      with_fixture_buffer(not_mule_xml, function()
        local notifications = run_command("MuleBuild")
        local warned = find_notification(notifications, "No Mule project detected")
        assert_true("non-Mule warning notification", warned ~= nil, "missing non-Mule warning")
        assert_equal("non-Mule warning level", warned.level, vim.log.levels.WARN)
      end)
    end)
  end)

  cleanup_project_artifacts(mule_root)
  vim.fn.delete(no_xsd_root, "rf")
  vim.fn.delete(command_scratch, "rf")
  if not ok then
    error(result, 0)
  end
end

local function foundation()
  require("onebeer.settings.filetypes")
  local detect = require("onebeer.mule.detect")
  local indexer = require("onebeer.mule.index")

  local mule_root = fixture_path("projects/basic-mule")
  local not_mule_xml = fixture_path("projects/not-mule/random.xml")
  local main_xml = mule_root .. "/src/main/mule/api.xml"
  local munit_xml = mule_root .. "/src/test/munit/api-test.xml"
  local resource_xml = mule_root .. "/src/main/resources/not-mule.xml"

  assert_equal("project root", detect.find_root(main_xml), mule_root)
  assert_equal("non-Mule root", detect.find_root(not_mule_xml), nil)
  assert_equal("current config is not Mule", detect.find_root(vim.fn.getcwd()), nil)
  assert_equal("main Mule XML discriminator", detect.is_mule_xml(main_xml), true)
  assert_equal("MUnit XML discriminator", detect.is_mule_xml(munit_xml), true)
  assert_equal("resource XML discriminator", detect.is_mule_xml(resource_xml), false)
  assert_equal("outside XML discriminator", detect.is_mule_xml(not_mule_xml), false)
  assert_equal("DataWeave filetype", vim.filetype.match({ filename = "sample.dwl" }), "dataweave")
  assert_equal("XML filetype unchanged", vim.filetype.match({ filename = "sample.xml" }), "xml")

  local index = assert(indexer.build(main_xml), "expected Mule index")
  assert_equal("index root", index.root, mule_root)
  assert_equal("Mule XML file count", #index.files.mule, 2)
  assert_equal("MUnit file count", #index.files.munit, 1)
  assert_equal("DataWeave file count", #index.files.dataweave, 1)
  assert_equal("flow count", #index.flows, 5)
  assert_equal("subflow count", #index.subflows, 1)
  assert_equal("config count", #index.configs, 4)
  assert_equal("APIKit config count", #index.apikit_configs, 3)
  assert_equal("DataWeave resource count", #index.dataweave_resources, 1)
  assert_equal("MUnit suite count", #index.munit_suites, 1)
  assert_equal("MUnit test count", #index.munit_suites[1].tests, 1)
end

local function maven_build()
  local maven = require("onebeer.mule.jobs.maven")
  local mule_root = fixture_path("projects/basic-mule")
  local not_mule_xml = fixture_path("projects/not-mule/random.xml")

  config.with({
    executables = {
      maven = config.fixture_bin_root() .. "/mvn-ok",
    },
  }, function()
    local ok, result = maven.build({ path = mule_root })
    assert_equal("maven ok", ok, true)
    assert_equal("maven ok exit", result.code, 0)
  end)

  config.with({
    executables = {
      maven = config.fixture_bin_root() .. "/mvn-fail",
    },
  }, function()
    local ok, result = maven.build({ path = mule_root })
    assert_equal("maven fail", ok, false)
    assert_equal("maven fail exit", result.code, 17)
    local qf = vim.fn.getqflist({ items = 1, title = 1 })
    assert_equal("maven quickfix title", qf.title, "Mule Maven Build")
    assert_equal("maven quickfix count", #qf.items, 1)
    local quickfix_path = qf.items[1].filename or vim.fn.bufname(qf.items[1].bufnr)
    assert_true("maven quickfix filename", quickfix_path:match("src/main/mule/api%.xml$") ~= nil, "missing filename")
    assert_equal("maven quickfix line", qf.items[1].lnum, 3)
    assert_equal("maven quickfix column", qf.items[1].col, 5)
  end)

  local ok, err = maven.build({ path = not_mule_xml })
  assert_equal("maven non-Mule refusal", ok, false)
  assert_equal("maven non-Mule message", err, "No Mule project detected")
  cleanup_fixture_buffers()
end

local function munit_runner()
  local munit = require("onebeer.mule.jobs.munit")
  local surefire = require("onebeer.mule.parsers.surefire")
  local mule_root = fixture_path("projects/basic-mule")
  local munit_xml = mule_root .. "/src/test/munit/api-test.xml"

  local tests = munit.discover(munit_xml)
  assert_equal("MUnit discovery count", #tests, 1)
  assert_equal("MUnit discovery name", tests[1].name, "api-main-test")
  assert_equal("MUnit nearest name", munit.nearest(munit_xml, 2).name, "api-main-test")
  assert_equal("MUnit selector", munit.selector(tests[1]), "api-test#api-main-test")

  local expected = {
    ["TEST-passed.xml"] = "passed",
    ["TEST-failed.xml"] = "failed",
    ["TEST-errored.xml"] = "errored",
    ["TEST-skipped.xml"] = "skipped",
  }
  for file, status in pairs(expected) do
    local results = surefire.parse_file(fixture_path("surefire/" .. file))
    assert_equal("Surefire result count " .. file, #results, 1)
    assert_equal("Surefire result status " .. file, results[1].status, status)
  end

  config.with({
    executables = {
      maven = config.fixture_bin_root() .. "/mvn-ok",
    },
  }, function()
    local ok, result = munit.run({ path = munit_xml, selector = "api-test#api-main-test" })
    assert_equal("MUnit ok", ok, true)
    assert_equal("MUnit ok exit", result.code, 0)
  end)

  config.with({
    executables = {
      maven = config.fixture_bin_root() .. "/mvn-fail",
    },
  }, function()
    local ok, result = munit.run({ path = munit_xml, selector = "api-test#api-main-test" })
    assert_equal("MUnit fail", ok, false)
    assert_equal("MUnit fail exit", result.code, 17)
    local qf = vim.fn.getqflist({ items = 1, title = 1 })
    assert_equal("MUnit quickfix title", qf.title, "Mule MUnit")
    assert_equal("MUnit quickfix count", #qf.items, 1)
  end)
  cleanup_fixture_buffers()
end

local function dataweave_cli()
  local dataweave = require("onebeer.mule.jobs.dataweave")
  local mule_root = fixture_path("projects/basic-mule")
  local dwl = fixture_path("projects/basic-mule/src/main/resources/dw/hello.dwl")

  config.with({
    executables = {
      dw = config.fixture_bin_root() .. "/dw-ok",
    },
  }, function()
    local ok, result = dataweave.validate_file(dwl)
    assert_equal("DataWeave validate ok", ok, true)
    assert_equal("DataWeave validate output", vim.trim(result.stdout or ""), "dw validate ok: " .. dwl)

    ok, result = dataweave.run_file(dwl)
    assert_equal("DataWeave run ok", ok, true)
    assert_equal("DataWeave run output", vim.split(vim.trim(result.stdout or ""), "\n")[1], "dw run ok: " .. dwl)
    local run_cwd = vim.split(vim.trim(result.stdout or ""), "\n")[2]:match("^dw cwd: (.+)$")
    assert_equal("DataWeave run cwd", vim.uv.fs_realpath(run_cwd), vim.uv.fs_realpath(mule_root))
  end)

  config.with({
    executables = {
      dw = config.fixture_bin_root() .. "/dw-fail",
    },
  }, function()
    local ok, result = dataweave.validate_file(dwl)
    assert_equal("DataWeave validate fail", ok, false)
    assert_equal("DataWeave validate fail exit", result.code, 9)
    local qf = vim.fn.getqflist({ items = 1, title = 1 })
    assert_equal("DataWeave quickfix title", qf.title, "Mule DataWeave")
    assert_equal("DataWeave quickfix line", qf.items[1].lnum, 2)
    assert_equal("DataWeave quickfix column", qf.items[1].col, 3)
    local validate_quickfix_path = qf.items[1].filename or vim.fn.bufname(qf.items[1].bufnr)
    assert_equal("DataWeave validate quickfix path", validate_quickfix_path, dwl)

    ok, result = dataweave.run_file(dwl)
    assert_equal("DataWeave run fail", ok, false)
    assert_equal("DataWeave run fail exit", result.code, 9)
    qf = vim.fn.getqflist({ items = 1, title = 1 })
    assert_equal("DataWeave run quickfix title", qf.title, "Mule DataWeave")
    local run_quickfix_path = qf.items[1].filename or vim.fn.bufname(qf.items[1].bufnr)
    assert_equal("DataWeave run quickfix path", run_quickfix_path, dwl)
  end)

  config.with({
    executables = {
      dw = config.fixture_bin_root() .. "/missing-dw",
    },
  }, function()
    local ok, err = dataweave.run_file(dwl)
    assert_equal("DataWeave missing executable", ok, false)
    assert_equal(
      "DataWeave missing message",
      err,
      ("DataWeave CLI `%s` is not executable"):format(config.fixture_bin_root() .. "/missing-dw")
    )
  end)
  cleanup_fixture_buffers()
end

local function apikit_navigation()
  local apikit = require("onebeer.mule.api.apikit")
  local detect = require("onebeer.mule.detect")
  local spec_paths = require("onebeer.mule.api.spec_paths")
  local mule_root = fixture_path("projects/basic-mule")
  local api_xml = mule_root .. "/src/main/mule/api.xml"
  local not_mule_xml = fixture_path("projects/not-mule/random.xml")
  local project = assert(detect.project(api_xml), "expected Mule project")

  local route = apikit.parse_flow_name([=[post:\platform-metrics\load:application\json:api-config]=])
  assert_equal("APIKit method", route.method, "post")
  assert_equal("APIKit path", route.path, "/platform-metrics/load")
  assert_equal("APIKit mime", route.mime, "application/json")
  assert_equal("APIKit config", route.config, "api-config")
  assert_equal("Malformed APIKit flow ignored", apikit.parse_flow_name("api-main"), nil)

  local target, err = apikit.route_for_flow(api_xml, [=[get:\health:api-config]=])
  assert_equal("APIKit route error", err, nil)
  assert_true(
    "APIKit spec path",
    target.spec_path:match("src/main/resources/api/basic%.raml$") ~= nil,
    "missing spec path"
  )
  assert_equal("APIKit route line", target.line, 4)

  target, err = apikit.route_for_flow(api_xml, [=[post:\platform-metrics\load:application\json:api-config]=])
  assert_equal("Nested RAML APIKit route error", err, nil)
  assert_equal("Nested RAML APIKit route line", target.line, 12)

  target, err = apikit.route_for_flow(api_xml, [=[get:\widgets\{widgetId}:oas-config]=])
  assert_equal("OAS APIKit route error", err, nil)
  assert_true(
    "OAS APIKit spec path",
    target.spec_path:match("src/main/resources/api/openapi%.yaml$") ~= nil,
    "missing spec path"
  )
  assert_equal("OAS APIKit route line", target.line, 7)

  target, err = apikit.route_for_flow(api_xml, [=[get:\remote:exchange-config]=])
  assert_equal("Exchange-only APIKit target", target, nil)
  assert_true(
    "Exchange-only APIKit error",
    err:find("Exchange resource specs are not resolved without a local file", 1, true) ~= nil,
    err or "missing error"
  )

  target, err = apikit.route_for_flow(not_mule_xml, [=[get:\health:api-config]=])
  assert_equal("Non-Mule APIKit target", target, nil)
  assert_equal("Non-Mule APIKit error", err, "Not a Mule XML buffer")

  local modules = spec_paths.exchange_modules(project)
  assert_equal("Exchange module count", #modules, 1)
  assert_true("Exchange module path", modules[1]:match("exchange_modules/.+/Health%.raml$") ~= nil, "missing module")
end

local function lemminx_catalog()
  local catalog = require("onebeer.mule.catalog")
  local detect = require("onebeer.mule.detect")
  local lemminx = require("onebeer.mule.integrations.lemminx")
  local mule_root = fixture_path("projects/basic-mule")
  local api_xml = mule_root .. "/src/main/mule/api.xml"
  local not_mule_xml = fixture_path("projects/not-mule/random.xml")
  local scratch = fixture_path("scratch/lemminx")
  local generated_catalog = scratch .. "/catalog.xml"
  local explicit_catalog = scratch .. "/explicit-catalog.xml"
  local empty_catalog = scratch .. "/empty-catalog.xml"
  local blocked_parent = scratch .. "/blocked-parent"
  local blocked_catalog = blocked_parent .. "/catalog.xml"
  local generic_resource_root = scratch .. "/generic-resource-mule"
  local generic_resource_xml = generic_resource_root .. "/src/main/resources/generic.xml"
  vim.fn.delete(scratch, "rf")
  assert_true("lemminx scratch mkdir", vim.fn.mkdir(scratch, "p") ~= 0, "failed to create scratch")

  local discovered = catalog.discover(assert(detect.project(api_xml), "expected Mule project"))
  assert_true("Catalog discovered mapping count", #discovered > 0, "expected at least one local XSD mapping")
  assert_equal("Catalog discovered namespace", discovered[1].uri, "urn:onebeer:mule:smoke")
  assert_true(
    "Catalog discovered XSD path",
    discovered[1].path:match("src/main/resources/schemas/onebeer%-smoke%.xsd$") ~= nil,
    "unexpected discovered xsd path"
  )

  local output, err = catalog.generate(api_xml, nil, generated_catalog)
  assert_equal("Discovered catalog error", err, nil)
  assert_equal("Discovered catalog output", output, generated_catalog)
  local generated_lines = table.concat(vim.fn.readfile(output), "\n")
  assert_true("Discovered catalog XML root", generated_lines:find("<catalog", 1, true) ~= nil, "missing catalog root")
  assert_true(
    "Discovered catalog uri entry",
    generated_lines:find("urn:onebeer:mule:smoke", 1, true) ~= nil,
    "missing uri"
  )
  assert_true("Discovered catalog has uri rows", generated_lines:find("<uri ", 1, true) ~= nil, "missing uri mapping")

  output, err = catalog.generate(api_xml, {
    {
      path = fixture_path("xsd/mule-core.xsd"),
      uri = "http://www.mulesoft.org/schema/mule/core/current/mule.xsd",
    },
  }, explicit_catalog)

  assert_equal("Explicit catalog error", err, nil)
  assert_true(
    "Explicit catalog output",
    output:match("scratch/lemminx/explicit%-catalog%.xml$") ~= nil,
    "missing output"
  )
  local explicit_lines = table.concat(vim.fn.readfile(output), "\n")
  assert_true("Explicit catalog XML root", explicit_lines:find("<catalog", 1, true) ~= nil, "missing catalog root")
  assert_true("Explicit catalog mapping", explicit_lines:find("mule-core.xsd", 1, true) ~= nil, "missing xsd mapping")

  output, err = catalog.generate(api_xml, {}, empty_catalog)
  assert_equal("Explicit empty catalog output", output, nil)
  assert_equal(
    "Explicit empty catalog error",
    err,
    "No Mule XML schema mappings found under src/main/resources or exchange_modules"
  )
  assert_equal("Explicit empty catalog not written", vim.uv.fs_stat(empty_catalog), nil)

  assert_true(
    "blocked catalog parent",
    vim.fn.writefile({ "blocker" }, blocked_parent) == 0,
    "failed to create blocker"
  )
  output, err = catalog.generate(api_xml, nil, blocked_catalog)
  assert_equal("Blocked catalog output", output, nil)
  assert_true(
    "Blocked catalog error",
    err ~= nil and err:find(blocked_catalog, 1, true) ~= nil,
    "missing blocked catalog path"
  )
  assert_equal("Blocked catalog not written", vim.uv.fs_stat(blocked_catalog), nil)

  local no_xsd_root = scratch .. "/no-xsd-mule"
  local copy_result = vim.fn.system({ "cp", "-R", mule_root, no_xsd_root })
  assert_equal("No-XSD fixture copy status", vim.v.shell_error, 0)
  assert_true("No-XSD fixture copy output", type(copy_result) == "string", "missing copy output")
  for _, path in ipairs(vim.fn.glob(no_xsd_root .. "/src/main/resources/**/*.xsd", false, true)) do
    vim.fn.delete(path)
  end
  for _, path in ipairs(vim.fn.glob(no_xsd_root .. "/exchange_modules/**/*.xsd", false, true)) do
    vim.fn.delete(path)
  end
  local no_xsd_xml = no_xsd_root .. "/src/main/mule/api.xml"
  local no_xsd_catalog = no_xsd_root .. "/.onebeer/mule-catalog.xml"
  output, err = catalog.generate(no_xsd_xml, nil, no_xsd_catalog)
  assert_equal("No-XSD discovered output", output, nil)
  assert_equal(
    "No-XSD discovered error",
    err,
    "No Mule XML schema mappings found under src/main/resources or exchange_modules"
  )
  assert_equal("No-XSD discovered catalog not written", vim.uv.fs_stat(no_xsd_catalog), nil)

  local project = assert(detect.project(api_xml), "expected Mule project")
  local project_catalog = catalog.default_path(project)
  local written, write_err = catalog.write(project_catalog, {
    {
      path = fixture_path("xsd/mule-core.xsd"),
      uri = "http://www.mulesoft.org/schema/mule/core/current/mule.xsd",
    },
  })
  assert_equal("Direct catalog write", written, true)
  assert_equal("Direct catalog write error", write_err, nil)
  local settings = lemminx.settings_for_path(api_xml)
  assert_equal(
    "LemMinX catalog setting",
    vim.uv.fs_realpath(settings.xml.catalogs[1]),
    vim.uv.fs_realpath(project_catalog)
  )
  assert_equal("LemMinX root settings", lemminx.settings_for_root(project.root), settings)
  assert_equal("LemMinX generic XML settings", lemminx.settings_for_path(not_mule_xml), {})

  local generic_copy_result = vim.fn.system({ "cp", "-R", mule_root, generic_resource_root })
  assert_equal("LemMinX generic resource copy status", vim.v.shell_error, 0)
  assert_true("LemMinX generic resource copy output", type(generic_copy_result) == "string", "missing copy output")
  assert_true(
    "LemMinX generic resource XML write",
    vim.fn.writefile({ "<resources />" }, generic_resource_xml) == 0,
    "failed to write generic resource XML"
  )

  local selected_root
  lemminx.root_dir(vim.fn.bufadd(api_xml), function(root)
    selected_root = root
  end)
  assert_equal("LemMinX Mule root", vim.fs.normalize(selected_root), vim.fs.normalize(project.root))

  local fallback_root
  lemminx.root_dir(vim.fn.bufadd(not_mule_xml), function(root)
    fallback_root = root
  end)
  assert_equal(
    "LemMinX generic XML root",
    vim.fs.normalize(fallback_root),
    vim.fs.root(vim.fs.dirname(not_mule_xml), { ".git" }) or vim.fs.dirname(not_mule_xml)
  )
  lemminx.root_dir(vim.fn.bufadd(generic_resource_xml), function(root)
    fallback_root = root
  end)
  assert_equal("LemMinX Mule resource XML root", vim.fs.normalize(fallback_root), vim.fs.dirname(generic_resource_xml))
  assert_equal("LemMinX Mule resource XML settings", lemminx.settings_for_path(generic_resource_xml), {})

  local notifications = {}
  local fake_client = {
    settings = {
      xml = {
        fileAssociations = { { pattern = "*.xml", systemId = "schema.xsd" } },
      },
    },
    notify = function(_, method, params)
      notifications[#notifications + 1] = { method = method, params = params }
      return true
    end,
  }
  assert_equal("LemMinX apply catalog", lemminx.apply(fake_client, api_xml), true)
  assert_equal("LemMinX apply catalog path", fake_client.settings.xml.catalogs[1], project_catalog)
  assert_equal("LemMinX existing settings retained", fake_client.settings.xml.fileAssociations[1].pattern, "*.xml")
  assert_equal("LemMinX apply notification count", #notifications, 1)
  assert_equal("LemMinX apply notification method", notifications[1].method, "workspace/didChangeConfiguration")
  assert_equal("LemMinX apply notification settings", notifications[1].params.settings, nil)

  local other_notifications = 0
  local other_client = {
    config = { root_dir = fixture_path("projects/not-mule") },
    settings = {},
    notify = function()
      other_notifications = other_notifications + 1
    end,
  }
  fake_client.config = { root_dir = project.root }
  local original_get_clients = vim.lsp.get_clients
  vim.lsp.get_clients = function(filter)
    assert_equal("LemMinX refresh client filter", filter, { name = "lemminx" })
    return { fake_client, other_client }
  end
  local refreshed_ok, refreshed = pcall(lemminx.refresh, api_xml)
  vim.lsp.get_clients = original_get_clients
  assert_equal("LemMinX refresh succeeds", refreshed_ok, true)
  assert_equal("LemMinX refresh count", refreshed, 1)
  assert_equal("LemMinX refresh notification count", #notifications, 2)
  assert_equal("LemMinX refresh ignores other project", other_notifications, 0)

  local lsp_config = vim.lsp.config.lemminx
  assert_true("LemMinX repo config root function", type(lsp_config.root_dir) == "function", "missing root_dir function")
  local initialized_config = { root_dir = project.root, settings = {} }
  lsp_config.before_init({}, initialized_config)
  assert_equal("LemMinX repo config catalog setting", initialized_config.settings.xml.catalogs[1], project_catalog)

  vim.fn.delete(project_catalog, "rf")
  vim.fn.delete(blocked_parent, "rf")
  vim.fn.delete(scratch, "rf")
  cleanup_project_artifacts(mule_root)
  cleanup_fixture_buffers()
end

local function anypoint_cli()
  local anypoint = require("onebeer.mule.jobs.anypoint")

  config.with({
    executables = {
      anypoint = config.fixture_bin_root() .. "/anypoint-ok",
    },
  }, function()
    local ok, result = anypoint.run({ "runtime-mgr:application:describe", "demo", "--output", "json" }, { json = true })
    assert_equal("Anypoint JSON ok", ok, true)
    assert_equal("Anypoint JSON status", result.status, "STARTED")

    ok, result = anypoint.run({ "fixture-null", "--output", "json" }, { json = true })
    assert_equal("Anypoint null ok", ok, true)
    assert_true("Anypoint null value", result == vim.NIL, "expected vim.NIL")

    ok, result = anypoint.run({ "fixture-boolean", "--output", "json" }, { json = true })
    assert_equal("Anypoint boolean ok", ok, true)
    assert_equal("Anypoint boolean value", result, true)

    ok, result = anypoint.run({ "fixture-number", "--output", "json" }, { json = true })
    assert_equal("Anypoint number ok", ok, true)
    assert_equal("Anypoint number value", result, 42)
  end)

  config.with({
    executables = {
      anypoint = config.fixture_bin_root() .. "/anypoint-auth",
    },
  }, function()
    local ok, result = anypoint.run({ "runtime-mgr:application:describe", "demo" }, { json = true })
    assert_equal("Anypoint auth ok", ok, false)
    assert_equal("Anypoint auth kind", result.kind, "auth")
  end)

  config.with({
    executables = {
      anypoint = config.fixture_bin_root() .. "/anypoint-text",
    },
  }, function()
    local ok, result = anypoint.run({ "runtime-mgr:application:describe", "demo", "--output", "json" }, { json = true })
    assert_equal("Anypoint text ok", ok, true)
    assert_equal("Anypoint text fallback", vim.trim(result), "plain text status")
  end)

  config.with({
    executables = {
      anypoint = config.fixture_bin_root() .. "/missing-anypoint",
    },
  }, function()
    local ok, result = anypoint.run({ "runtime-mgr:application:describe", "demo" })
    assert_equal("Anypoint missing ok", ok, false)
    assert_equal("Anypoint missing kind", result.kind, "missing")
  end)
end

local function neotest_adapter()
  local neotest = require("onebeer.mule.integrations.neotest")
  local adapter = neotest.adapter()
  local mule_root = fixture_path("projects/basic-mule")
  local munit_xml = mule_root .. "/src/test/munit/api-test.xml"
  local not_mule_xml = fixture_path("projects/not-mule/random.xml")

  assert_equal("Neotest adapter name", adapter.name, "mule-munit")
  assert_equal("Neotest MUnit file", adapter.is_test_file(munit_xml), true)
  assert_equal("Neotest non-Mule file", adapter.is_test_file(not_mule_xml), false)

  local tree = adapter.discover_positions(munit_xml)
  assert_true("Neotest positions", tree ~= nil, "missing MUnit position tree")
  assert_equal("Neotest root path", tree:data().path, munit_xml)

  local discovered_test
  for _, child in ipairs(tree:children()) do
    local data = child:data()
    if data.name == "api-main-test" then
      discovered_test = data
      break
    end
  end
  assert_true("Neotest child position", discovered_test ~= nil, "missing api-main-test child")
  assert_true(
    "Neotest child id",
    discovered_test.id:find("api-test#api-main-test", 1, true) ~= nil,
    "missing selector in child id"
  )

  local test = require("onebeer.mule.jobs.munit").discover_file(munit_xml)[1]
  local spec = adapter.build_spec({ tree = {
    data = function()
      return test
    end,
  } })
  assert_equal("Neotest cwd", spec.cwd, mule_root)
  assert_equal("Neotest DAP honesty", spec.context.strategy_supported, false)
  assert_equal("Neotest command selector", spec.command[#spec.command], "-Dmunit.test=api-test#api-main-test")

  local configured_maven = { config.fixture_bin_root() .. "/mvn-ok", "--batch-mode" }
  local configured_spec = config.with({
    executables = {
      maven = configured_maven,
    },
  }, function()
    return adapter.build_spec({ tree = {
      data = function()
        return test
      end,
    } })
  end)
  assert_true("Neotest configured spec", configured_spec ~= nil, "missing configured build spec")
  assert_equal("Neotest configured command head", configured_spec.command[1], configured_maven[1])
  assert_equal("Neotest configured command arg", configured_spec.command[2], configured_maven[2])
  assert_equal(
    "Neotest configured command selector",
    configured_spec.command[#configured_spec.command],
    "-Dmunit.test=api-test#api-main-test"
  )

  local missing_maven_spec = config.with({
    executables = {
      maven = {},
    },
  }, function()
    return adapter.build_spec({ tree = {
      data = function()
        return test
      end,
    } })
  end)
  assert_equal("Neotest missing maven command", missing_maven_spec, nil)

  with_surefire_reports(mule_root, {
    { fixture = "surefire/TEST-passed.xml", name = "TEST-api-test.xml" },
    { fixture = "surefire/TEST-secondary-suite.xml", name = "TEST-secondary-suite.xml" },
  }, function(report_paths)
    local results = neotest.result_map(report_paths)
    local passed_id = munit_xml .. "::api-test#api-main-test"
    local failed_id = mule_root .. "/src/test/munit/api-secondary-test.xml::api-secondary-test#api-main-test"
    assert_equal("Neotest plain result key", results["api-main-test"], nil)
    assert_equal("Neotest passed result", results[passed_id].status, "passed")
    assert_equal("Neotest failed result", results[failed_id].status, "failed")
    assert_equal("Neotest failed message", results[failed_id].errors[1].message, "payload mismatch")
  end)
end

local function dap_feasibility()
  local dap = require("onebeer.mule.integrations.dap")
  local previous = vim.g.onebeer_mule_enable_experimental_dap
  vim.g.onebeer_mule_enable_experimental_dap = false
  local ok, err = dap.setup()
  vim.g.onebeer_mule_enable_experimental_dap = previous
  assert_equal("DAP disabled", ok, false)
  assert_equal("DAP disabled message", err, "Mule DAP is disabled until a JDWP smoke test proves support")
end

local function deliberate_fail()
  error("deliberate smoke failure", 0)
end

local function sorted_ids(ids)
  table.sort(ids)
  return ids
end

local function stage_snapshot()
  local fixture_root = config.fixture_root()
  local artifact_paths = {
    fixture_root .. "/scratch",
    fixture_root .. "/projects/basic-mule/.onebeer",
    fixture_root .. "/projects/basic-mule/target",
  }
  local artifacts = {}
  for _, path in ipairs(artifact_paths) do
    artifacts[path] = vim.uv.fs_stat(path) ~= nil
  end

  local buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      buffers[#buffers + 1] = buf
    end
  end

  return {
    artifacts = artifacts,
    buffers = sorted_ids(buffers),
    current_buf = vim.api.nvim_get_current_buf(),
    current_win = vim.api.nvim_get_current_win(),
    notify = vim.notify,
    windows = sorted_ids(vim.api.nvim_list_wins()),
  }
end

---@param name string
---@param before table
local function assert_stage_isolated(name, before)
  assert_equal(name .. " artifact state", stage_snapshot().artifacts, before.artifacts)
  assert_equal(name .. " buffer state", stage_snapshot().buffers, before.buffers)
  assert_equal(name .. " current buffer", vim.api.nvim_get_current_buf(), before.current_buf)
  assert_equal(name .. " current window", vim.api.nvim_get_current_win(), before.current_win)
  assert_true(name .. " notify state", vim.notify == before.notify, "vim.notify was not restored")
  assert_equal(name .. " window state", stage_snapshot().windows, before.windows)
end

local stages = {
  commands = commands,
  foundation = foundation,
  ["dataweave-cli"] = dataweave_cli,
  ["dap-feasibility"] = dap_feasibility,
  ["apikit-navigation"] = apikit_navigation,
  ["anypoint-cli"] = anypoint_cli,
  harness = harness,
  ["harness-deliberate-fail"] = deliberate_fail,
  ["lemminx-catalog"] = lemminx_catalog,
  ["maven-build"] = maven_build,
  ["munit-runner"] = munit_runner,
  ["neotest-adapter"] = neotest_adapter,
}

local success_stages = {
  "harness",
  "foundation",
  "maven-build",
  "munit-runner",
  "dataweave-cli",
  "lemminx-catalog",
  "apikit-navigation",
  "anypoint-cli",
  "neotest-adapter",
  "dap-feasibility",
  "commands",
}

---@param name string
local function run_stage(name)
  local runner = stages[name]
  if runner == nil then
    error(("Unknown Mule smoke stage: %s"):format(name), 0)
  end
  runner()
end

---@param stage? string
---@return nil
function M.run(stage)
  local name = stage or "harness"
  local ok, err = pcall(function()
    if name ~= "all" then
      run_stage(name)
      return
    end

    for _, stage_name in ipairs(success_stages) do
      local before = stage_snapshot()
      run_stage(stage_name)
      assert_stage_isolated(stage_name, before)
    end
  end)
  if ok then
    return
  end

  if #vim.api.nvim_list_uis() == 0 then
    vim.api.nvim_err_writeln(tostring(err))
    vim.cmd("cquit")
    return
  end

  error(err, 0)
end

return M
