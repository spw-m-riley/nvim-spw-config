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

local mason_registry = (function()
  local ok, registry = pcall(require, "mason-registry")
  if ok then
    return registry
  end
  return nil
end)()

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

---@param name string
---@param cb? OneBeerInstallDone
---@return boolean
local function ensure_install(name, cb)
  local spec = install_specs[name]
  if not spec then
    if cb then
      cb(false)
    end
    return false
  end

  if spec.check and spec.check() then
    spec.status = "installed"
    resolve_waiters(spec, true)
    if cb then
      cb(true)
    end
    return true
  end

  if spec.status == "installed" then
    if cb then
      cb(true)
    end
    return true
  end

  if spec.status == "pending" and spec.check and spec.check() then
    spec.status = "installed"
    resolve_waiters(spec, true)
    if cb then
      cb(true)
    end
    return true
  end

  if cb then
    table.insert(spec.waiters, cb)
  end

  if spec.status == "installing" then
    return false
  end

  spec.status = "installing"

  local function run_after_dependencies(ok)
    if not ok then
      spec.status = "failed"
      resolve_waiters(spec, false)
      return
    end
    spec.run(function(result_ok)
      spec.status = result_ok and "installed" or "failed"
      resolve_waiters(spec, result_ok)
    end)
  end

  local needs = spec.needs
  if needs and #needs > 0 then
    local remaining = #needs
    local failed = false
    local function on_dependency_finished(ok)
      if not ok then
        failed = true
      end
      remaining = remaining - 1
      if remaining == 0 then
        run_after_dependencies(not failed)
      end
    end
    for _, dep in ipairs(needs) do
      ensure_install(dep, on_dependency_finished)
    end
  else
    run_after_dependencies(true)
  end

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
    vim.health.ok(("`%s` is installed"):format(name))
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
    vim.health.ok(("`%s` is installed"):format(name))
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
    vim.health.ok(("`%s` is installed"):format(name))
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
      vim.health.ok(("`%s` is available via `%s`"):format(label, name))
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
    vim.health.ok(("`%s` is installed (optional fast path)"):format(name))
    return true
  end

  vim.health.info(("`%s` is optional. %s"):format(name, instruction))
  return false
end

---Run the OneBeer health checks and emit vim.health diagnostics.
---@return nil
function M.check()
  vim.health.start("Neovim Version")
  if vim.fn.has("nvim-0.11.0") == 1 then
    vim.health.ok("Using Neovim >= 0.11.0")
  else
    vim.health.report_error("Neovim >= 0.11.0 is required")
  end

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

  ---@type OneBeerMissingList
  local missing = {}

  check_exes(exes, missing)

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

  if #missing > 0 then
    local lines = { "Install missing dependencies now?" }
    for _, item in ipairs(missing) do
      if item.kind == "mason" then
        table.insert(lines, ("- %s (Mason)"):format(item.name))
      else
        table.insert(lines, ("- %s"):format(item.name))
      end
    end

    local choice = vim.fn.confirm(table.concat(lines, "\n"), "&Yes\n&No", 2)
    if choice == 1 then
      for _, item in ipairs(missing) do
        if item.kind == "external" then
          ensure_dependency_install(item.name)
        elseif item.kind == "mason" then
          if mason_registry and mason_installable[item.name] and mason_registry.has_package(item.name) then
            local ok, pkg = pcall(mason_registry.get_package, item.name)
            if ok and pkg and not pkg:is_installed() then
              local success, err = pcall(function()
                pkg:install()
              end)
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
          else
            vim.schedule(function()
              vim.notify(("Please install %s via :Mason"):format(item.name), vim.log.levels.WARN, { title = "Mason" })
            end)
          end
        end
      end
    end
  end
end

return M
