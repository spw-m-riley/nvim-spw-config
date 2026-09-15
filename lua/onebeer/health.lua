---Health checks and optional installers for OneBeer dependencies.
---@class OneBeerHealth
local M = {}

---@alias OneBeerInstallStatus "pending"|"installing"|"installed"|"failed"
---@alias OneBeerInstallDone fun(ok:boolean)
---@alias OneBeerInstallRunner fun(done:OneBeerInstallDone|nil)

---@class OneBeerRunCommandOpts
---@field title? string
---@field cmd string[]
---@field start_msg? string
---@field success_msg? string
---@field failure_msg? string

---@class OneBeerInstallSpec
---@field needs string[]|nil
---@field check fun():boolean
---@field run OneBeerInstallRunner
---@field waiters OneBeerInstallDone[]|nil
---@field status OneBeerInstallStatus|nil

---@class OneBeerMissingItem
---@field kind "external"|"mason"
---@field name string

---@class OneBeerMissingList
---@field [integer] OneBeerMissingItem
---@field _set table<string, boolean>|nil

---@class OneBeerCommandSpec
---@field name string
---@field instruction string

local mason_registry

---@return MasonRegistry|nil
local function get_mason_registry()
  if mason_registry ~= nil then
    return mason_registry
  end

  local ok, registry = pcall(require, "mason-registry")
  mason_registry = ok and registry or false
  return mason_registry or nil
end

local version_commands = {
  actionlint = { "actionlint", "-version" },
  beautysh = { "beautysh", "--version" },
  brew = { "brew", "--version" },
  eslint = { "eslint", "--version" },
  eslint_d = { "eslint_d", "--version" },
  fzf = { "fzf", "--version" },
  git = { "git", "--version" },
  gitlint = { "gitlint", "--version" },
  gleam = { "gleam", "--version" },
  go = { "go", "version" },
  hadolint = { "hadolint", "--version" },
  jq = { "jq", "--version" },
  markdownlint = { "markdownlint", "--version" },
  mise = { "mise", "--version" },
  node = { "node", "--version" },
  oxlint = { "oxlint", "--version" },
  prettier = { "prettier", "--version" },
  prettierd = { "prettierd", "--version" },
  quicktype = { "quicktype", "--version" },
  ruff = { "ruff", "--version" },
  rg = { "rg", "--version" },
  rubocop = { "rubocop", "--version" },
  ["ruby-lsp"] = { "ruby-lsp", "--version" },
  rustfmt = { "rustfmt", "--version" },
  selene = { "selene", "--version" },
  shellcheck = { "shellcheck", "--version" },
  sqlfluff = { "sqlfluff", "--version" },
  stylua = { "stylua", "--version" },
  tflint = { "tflint", "--version" },
  woke = { "woke", "--version" },
  ["write-good"] = { "write-good", "--version" },
  yamllint = { "yamllint", "--version" },
  zls = { "zls", "--version" },
  zig = { "zig", "version" },
}

---@param title string
---@param msg string|nil
---@param level? integer
local function notify(title, msg, level)
  if not msg or msg == "" then
    return
  end
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.INFO, { title = title })
  end)
end

---@param text string|nil
---@return string|nil
local function first_non_empty_line(text)
  if not text or text == "" then
    return nil
  end

  for _, line in ipairs(vim.split(text, "\n", { trimempty = true })) do
    local trimmed = vim.trim(line)
    if trimmed ~= "" then
      return trimmed
    end
  end

  return nil
end

---@param result vim.SystemCompleted
---@return string|nil
local function system_result_output(result)
  local output = result.stdout or ""
  if result.stderr and result.stderr ~= "" then
    output = output == "" and result.stderr or (output .. "\n" .. result.stderr)
  end
  if output == "" then
    return nil
  end
  return output
end

---@param cmd string[]
---@return string|nil
local function capture_with_vim_system(cmd)
  local ok, result = pcall(function()
    return vim.system(cmd, { text = true }):wait(1000)
  end)
  if not ok or not result or result.code ~= 0 then
    return nil
  end
  return system_result_output(result)
end

---@param cmd string[]
---@return string|nil
local function capture_with_shell(cmd)
  local output = vim.fn.system(cmd)
  return vim.v.shell_error == 0 and output or nil
end

---@param cmd string[]
---@return string|nil
local function capture_command_output(cmd)
  if vim.system then
    return capture_with_vim_system(cmd)
  end
  return capture_with_shell(cmd)
end

---@param name string
---@return string|nil
local function executable_version(name)
  local cmd = version_commands[name]
  if not cmd then
    return nil
  end

  return first_non_empty_line(capture_command_output(cmd))
end

---@param name string
---@param note? string
---@return string
local function installed_message(name, note)
  local details = {}
  local version = executable_version(name)
  if version then
    table.insert(details, version)
  end
  if note and note ~= "" then
    table.insert(details, note)
  end

  if #details == 0 then
    return ("`%s` is installed"):format(name)
  end

  return ("`%s` is installed (%s)"):format(name, table.concat(details, "; "))
end

---@param label string
---@param name string
---@return string
local function available_message(label, name)
  local version = executable_version(name)
  if version then
    return ("`%s` is available via `%s` (%s)"):format(label, name, version)
  end

  return ("`%s` is available via `%s`"):format(label, name)
end

---@param opts OneBeerRunCommandOpts
---@param done? OneBeerInstallDone
local function run_command(opts, done)
  local title = opts.title or "Installer"
  notify(title, opts.start_msg)
  local function finish(ok, err)
    if ok then
      notify(title, opts.success_msg or "Installation complete")
    else
      local message = opts.failure_msg or "Installation failed"
      if err and err ~= "" then
        message = ("%s: %s"):format(message, err)
      end
      notify(title, message, vim.log.levels.ERROR)
    end
    if done then
      done(ok)
    end
  end

  local cmd = opts.cmd
  if vim.system then
    vim.system(cmd, { text = true }, function(result)
      local ok = result.code == 0
      local err
      if not ok then
        err = vim.trim((result.stderr ~= "" and result.stderr) or result.stdout or ("exit code " .. result.code))
      end
      finish(ok, err)
    end)
  else
    local job = vim.fn.jobstart(cmd, {
      on_exit = function(_, code)
        finish(code == 0, code == 0 and nil or ("exit " .. code))
      end,
    })
    if job <= 0 then
      finish(false, "failed to start installer job")
    end
  end
end

---@param pkg string
---@param label? string
---@return OneBeerInstallRunner
local function brew_install(pkg, label)
  return function(done)
    run_command({
      title = "Homebrew",
      cmd = { "brew", "install", pkg },
      start_msg = ("Installing %s via Homebrew..."):format(label or pkg),
      success_msg = ("%s installed via Homebrew."):format(label or pkg),
      failure_msg = ("Failed to install %s via Homebrew"):format(label or pkg),
    }, done)
  end
end

---@param spec string
---@param label? string
---@return OneBeerInstallRunner
local function mise_use(spec, label)
  return function(done)
    run_command({
      title = "mise",
      cmd = { "mise", "use", "--global", spec },
      start_msg = ("Installing %s via mise..."):format(label or spec),
      success_msg = ("%s configured via mise."):format(label or spec),
      failure_msg = ("Failed to configure %s via mise"):format(label or spec),
    }, done)
  end
end

---@param module string
---@param label? string
---@return OneBeerInstallRunner
local function go_install(module, label)
  return function(done)
    run_command({
      title = "go install",
      cmd = { "go", "install", module },
      start_msg = ("Installing %s via `go install`..."):format(label or module),
      success_msg = ("%s installed via `go install`."):format(label or module),
      failure_msg = ("Failed to install %s via `go install`"):format(label or module),
    }, done)
  end
end

---@param pkg string
---@param label? string
---@return OneBeerInstallRunner
local function npm_global(pkg, label)
  return function(done)
    run_command({
      title = "npm",
      cmd = { "npm", "install", "-g", pkg },
      start_msg = ("Installing %s via npm..."):format(label or pkg),
      success_msg = ("%s installed globally via npm."):format(label or pkg),
      failure_msg = ("Failed to install %s via npm"):format(label or pkg),
    }, done)
  end
end

---@type table<string, OneBeerInstallSpec>
local install_specs = {
  brew = {
    check = function()
      return vim.fn.executable("brew") == 1
    end,
    run = function(done)
      notify(
        "Homebrew",
        'Homebrew is required but must be installed manually. Run `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` in a terminal.',
        vim.log.levels.ERROR
      )
      if done then
        done(false)
      end
    end,
  },
  mise = {
    needs = { "brew" },
    check = function()
      return vim.fn.executable("mise") == 1
    end,
    run = brew_install("mise", "mise"),
  },
  git = {
    needs = { "brew" },
    check = function()
      return vim.fn.executable("git") == 1
    end,
    run = brew_install("git", "git"),
  },
  rg = {
    needs = { "brew" },
    check = function()
      return vim.fn.executable("rg") == 1
    end,
    run = brew_install("ripgrep", "ripgrep"),
  },
  fzf = {
    needs = { "brew" },
    check = function()
      return vim.fn.executable("fzf") == 1
    end,
    run = brew_install("fzf", "fzf"),
  },
  jq = {
    needs = { "brew" },
    check = function()
      return vim.fn.executable("jq") == 1
    end,
    run = brew_install("jq", "jq"),
  },
  node = {
    needs = { "mise" },
    check = function()
      return vim.fn.executable("node") == 1
    end,
    run = mise_use("node@latest", "Node.js"),
  },
  go = {
    needs = { "mise" },
    check = function()
      return vim.fn.executable("go") == 1
    end,
    run = mise_use("go@latest", "Go"),
  },
  gojson = {
    needs = { "go" },
    check = function()
      return vim.fn.executable("gojson") == 1
    end,
    run = go_install("github.com/ChimeraCoder/gojson/gojson@latest", "gojson"),
  },
  quicktype = {
    needs = { "node" },
    check = function()
      return vim.fn.executable("quicktype") == 1
    end,
    run = npm_global("quicktype", "quicktype"),
  },
}

for _, spec in pairs(install_specs) do
  spec.needs = spec.needs or {}
  spec.waiters = {}
  spec.status = "pending"
end

---@type table<string, string>
local dependency_install_map = {
  brew = "brew",
  mise = "mise",
  git = "git",
  rg = "rg",
  fzf = "fzf",
  jq = "jq",
  node = "node",
  go = "go",
  gojson = "gojson",
  quicktype = "quicktype",
}

---@param spec OneBeerInstallSpec
---@param ok boolean
local function resolve_waiters(spec, ok)
  local waiters = spec.waiters
  spec.waiters = {}
  for _, waiter in ipairs(waiters) do
    pcall(waiter, ok)
  end
end

---@param spec OneBeerInstallSpec
---@param ok boolean
---@param cb? OneBeerInstallDone
local function mark_install_available(spec, ok, cb)
  spec.status = ok and "installed" or "failed"
  resolve_waiters(spec, ok)
  if cb then
    cb(ok)
  end
end

---@param spec OneBeerInstallSpec
local ensure_install
local function start_install(spec)
  local function run_after_dependencies(ok)
    if not ok then
      mark_install_available(spec, false)
      return
    end
    spec.run(function(result_ok)
      mark_install_available(spec, result_ok)
    end)
  end

  local needs = spec.needs or {}
  if #needs == 0 then
    run_after_dependencies(true)
    return
  end

  local remaining = #needs
  local failed = false
  local function on_dependency_finished(ok)
    failed = failed or not ok
    remaining = remaining - 1
    if remaining == 0 then
      run_after_dependencies(not failed)
    end
  end
  for _, dep in ipairs(needs) do
    ensure_install(dep, on_dependency_finished)
  end
end

---@param spec OneBeerInstallSpec
---@param cb? OneBeerInstallDone
---@return boolean
local function resolve_known_install(spec, cb)
  if spec.check and spec.check() then
    mark_install_available(spec, true, cb)
    return true
  end
  if spec.status == "installed" then
    if cb then
      cb(true)
    end
    return true
  end
  if spec.status == "pending" and spec.check and spec.check() then
    mark_install_available(spec, true, cb)
    return true
  end
  return false
end

---@param name string
---@param cb? OneBeerInstallDone
---@return boolean
ensure_install = function(name, cb)
  local spec = install_specs[name]
  if not spec then
    if cb then
      cb(false)
    end
    return false
  end
  if resolve_known_install(spec, cb) then
    return true
  end
  if cb then
    table.insert(spec.waiters, cb)
  end
  if spec.status == "installing" then
    return false
  end

  spec.status = "installing"
  start_install(spec)
  return false
end

---@param name string
local function ensure_dependency_install(name)
  local installer = dependency_install_map[name]
  if installer then
    ensure_install(installer)
  end
end

local mason_installable = {
  stylua = true,
  shfmt = true,
  oxlint = true,
  selene = true,
  shellcheck = true,
  yamllint = true,
  hadolint = true,
  gitlint = true,
  actionlint = true,
}

---Queue missing tools for optional installation at end of :checkhealth
---@param missing OneBeerMissingList|nil
---@param kind "external"|"mason"
---@param name string
local function queue_missing(missing, kind, name)
  if not missing then
    return
  end
  missing._set = missing._set or {}
  local key = (kind or "unknown") .. ":" .. name
  if missing._set[key] then
    return
  end
  missing._set[key] = true
  table.insert(missing, { kind = kind, name = name })
end

---Check if an executable is installed
---@param name string
---@param instruction string
---@param missing? OneBeerMissingList
---@return boolean
local function check_executable(name, instruction, missing)
  if vim.fn.executable(name) == 1 then
    vim.health.ok(installed_message(name))
    return true
  end

  vim.health.warn(("`%s` is not installed. %s"):format(name, instruction))
  queue_missing(missing, "external", name)
  return false
end

---Check multiple executables
---@param commands OneBeerCommandSpec[]
---@param missing? OneBeerMissingList
---@return nil
local function check_exes(commands, missing)
  for _, cmd in ipairs(commands) do
    check_executable(cmd.name, cmd.instruction, missing)
  end
end

---Check formatter/linter is installed
---@param name string
---@param missing? OneBeerMissingList
---@return nil
local function check_formatter(name, missing)
  if vim.fn.executable(name) == 1 then
    vim.health.ok(installed_message(name))
    return
  end

  vim.health.warn(("`%s` is not installed. Please use :Mason to install"):format(name))
  queue_missing(missing, "mason", name)
end

---Check an executable without offering automated installation.
---@param name string
---@param instruction string
---@return boolean
local function check_manual_executable(name, instruction)
  if vim.fn.executable(name) == 1 then
    vim.health.ok(installed_message(name))
    return true
  end

  vim.health.warn(("`%s` is not installed. %s"):format(name, instruction))
  return false
end

---Check that at least one executable in a preferred/fallback chain is available.
---@param names string[]
---@param label string
---@param instruction string
---@return boolean
local function check_any_executable(names, label, instruction)
  for _, name in ipairs(names) do
    if vim.fn.executable(name) == 1 then
      vim.health.ok(available_message(label, name))
      return true
    end
  end

  vim.health.warn(("`%s` is not installed. %s"):format(label, instruction))
  return false
end

---Check an optional executable and report it as informational when missing.
---@param name string
---@param instruction string
---@return boolean
local function check_optional_executable(name, instruction)
  if vim.fn.executable(name) == 1 then
    vim.health.ok(installed_message(name, "optional fast path"))
    return true
  end

  vim.health.info(("`%s` is optional. %s"):format(name, instruction))
  return false
end

---@param name string
---@param instruction string
---@return boolean
local function check_runtime_executable(name, instruction)
  if vim.fn.executable(name) == 1 then
    vim.health.ok(installed_message(name, "runtime-managed surface"))
    return true
  end

  vim.health.info(("`%s` is not installed on this machine. %s"):format(name, instruction))
  return false
end

local function check_neovim_version()
  vim.health.start("Neovim Version")
  if vim.fn.has("nvim-0.13.0") == 1 then
    local version = first_non_empty_line(vim.api.nvim_exec2("version", { output = true }).output)
    vim.health.ok(version and ("%s (requires >= 0.13.0)"):format(version) or "Using Neovim >= 0.13.0")
  else
    vim.health.report_error("Neovim >= 0.13.0 is required")
  end
end

---@param missing OneBeerMissingList
local function check_config_tools(missing)
  vim.health.start("OneBeer Config")
  ---@type OneBeerCommandSpec[]
  local exes = {
    { name = "git", instruction = "Install git via `brew install git`" },
    { name = "rg", instruction = "Install ripgrep via `brew install ripgrep`" },
    {
      name = "brew",
      instruction = 'Install Homebrew via `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`',
    },
    { name = "node", instruction = "Install Node.js via `brew install node` or use mise" },
    { name = "go", instruction = "Install Go via `brew install go` or use mise" },
    { name = "fzf", instruction = "Install fzf via `brew install fzf`" },
    { name = "jq", instruction = "Install jq via `brew install jq`" },
    { name = "gojson", instruction = "Install gojson via `go install github.com/ChimeraCoder/gojson/gojson@latest`" },
    { name = "quicktype", instruction = "Install quicktype via `npm install -g quicktype`" },
    { name = "mise", instruction = "Install mise via `brew install mise`" },
  }
  check_exes(exes, missing)
end

---@param missing OneBeerMissingList
local function check_formatters_and_linters(missing)
  vim.health.start("Formatters & Linters")
  check_formatter("stylua", missing)
  check_any_executable(
    { "shfmt", "beautysh" },
    "shfmt/beautysh",
    "Install `shfmt` via `brew install shfmt` or provide `beautysh` as a fallback formatter"
  )
  check_any_executable(
    { "prettierd", "prettier" },
    "prettierd/prettier",
    "Install `prettierd` via `npm install -g @fsouza/prettierd` or install `prettier` via `npm install -g prettier`"
  )
  check_manual_executable("eslint", "Install via `npm install -g eslint`")
  check_optional_executable(
    "eslint_d",
    "Install via `npm install -g eslint_d` to enable the faster JS/TS InsertLeave lint path"
  )
  check_formatter("oxlint", missing)
  check_formatter("selene", missing)
  check_manual_executable("markdownlint", "Install via `npm install -g markdownlint-cli`")
  check_manual_executable("write-good", "Install via `npm install -g write-good`")
  check_manual_executable("woke", "Install via `brew install woke`")
  check_formatter("shellcheck", missing)
  check_formatter("yamllint", missing)
  check_manual_executable("tflint", "Install via `brew install tflint`")
  check_formatter("hadolint", missing)
  check_formatter("gitlint", missing)
  check_formatter("actionlint", missing)
end

local function check_language_tooling()
  vim.health.start("Language Tooling")
  check_runtime_executable(
    "ruff",
    "Install via `uv tool install ruff`, `brew install ruff`, or `pipx install ruff` to enable Ruff formatting + LSP support"
  )
  check_manual_executable("rustfmt", "Install via `rustup component add rustfmt`")
  check_manual_executable("sqlfluff", "Install via `pipx install sqlfluff` or `uv tool install sqlfluff`")
  check_runtime_executable(
    "ruby-lsp",
    "Install via `gem install ruby-lsp` in the Ruby runtime Neovim uses to enable Ruby LSP support"
  )
  check_runtime_executable(
    "rubocop",
    "Install via `gem install rubocop` in the Ruby runtime Neovim uses to enable Ruby formatting"
  )
  check_runtime_executable("gleam", "Install Gleam to enable the runtime-managed Gleam LSP + formatter surface")
  check_runtime_executable("zig", "Install Zig to enable `zig fmt` support")
  check_runtime_executable("zls", "Install `zls` or let Mason manage it to enable Zig LSP support")
  vim.health.info(
    "Validate Mason-managed servers and attachment separately with `:checkhealth mason`, `:checkhealth vim.lsp`, and `:checkhealth ts-install`."
  )
end

---@param item OneBeerMissingItem
local function install_mason_item(item)
  local registry = get_mason_registry()
  if not (registry and mason_installable[item.name] and registry.has_package(item.name)) then
    vim.schedule(function()
      vim.notify(("Please install %s via :Mason"):format(item.name), vim.log.levels.WARN, { title = "Mason" })
    end)
    return
  end

  local ok, pkg = pcall(registry.get_package, item.name)
  if not (ok and pkg and not pkg:is_installed()) then
    return
  end
  local success, err = pcall(pkg.install, pkg)
  if not success then
    vim.schedule(function()
      vim.notify(
        ("Failed to queue Mason install for %s: %s"):format(item.name, err),
        vim.log.levels.ERROR,
        { title = "Mason" }
      )
    end)
  end
end

---@param item OneBeerMissingItem
local function install_missing_item(item)
  if item.kind == "external" then
    ensure_dependency_install(item.name)
  elseif item.kind == "mason" then
    install_mason_item(item)
  end
end

---@param missing OneBeerMissingList
---@return boolean
local function offer_missing_installs(missing)
  if #missing == 0 then
    return true
  end
  if #vim.api.nvim_list_uis() == 0 then
    vim.health.info(
      "Automatic install prompts are skipped in headless sessions; rerun `:checkhealth onebeer` interactively to install missing tools."
    )
    return false
  end

  local lines = { "Install missing dependencies now?" }
  for _, item in ipairs(missing) do
    table.insert(lines, item.kind == "mason" and ("- %s (Mason)"):format(item.name) or ("- %s"):format(item.name))
  end
  if vim.fn.confirm(table.concat(lines, "\n"), "&Yes\n&No", 2) ~= 1 then
    return true
  end
  for _, item in ipairs(missing) do
    install_missing_item(item)
  end
  return true
end

---Run the OneBeer health checks and emit vim.health diagnostics.
---@return nil
function M.check()
  check_neovim_version()
  local missing = {}
  check_config_tools(missing)
  check_formatters_and_linters(missing)
  check_language_tooling()

  local ok_mule_health, mule_health = pcall(require, "onebeer.mule.health")
  if ok_mule_health then
    mule_health.check()
  else
    vim.health.warn("MuleSoft health checks could not be loaded: " .. tostring(mule_health))
  end

  offer_missing_installs(missing)
end

return M
