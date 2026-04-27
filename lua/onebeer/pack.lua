---@module "onebeer.pack"
local autocmds = require("onebeer.autocmds.helpers")
local modules = require("onebeer.pack_modules").list()

---@class onebeer.PackSpec : onebeer.PluginSpec
---@field name string
---@field src string
---@field main string
---@field lazy boolean
---@field priority integer
---@field dependencies string[]
---@field keys onebeer.PluginKey[]

---@type string[]
local disabled_plugins = {
  "2html_plugin",
  "getscript",
  "getscriptPlugin",
  "gzip",
  "logiPat",
  "matchit",
  "matchparen",
  "netrw",
  "netrwFileHandlers",
  "netrwPlugin",
  "netrwSettings",
  "rrhelper",
  "spellfile_plugin",
  "tar",
  "tarPlugin",
  "tohtml",
  "tutor",
  "vimball",
  "vimballPlugin",
  "zip",
  "zipPlugin",
}

---@class onebeer.PackRegistry
---@field specs table<string, onebeer.PackSpec>
---@field ordered string[]

---@type table<string, onebeer.PackSpec>, string[], table<string, boolean>, table<string, string>
local specs, ordered, loaded, command_stubs = {}, {}, {}, {}
local runtime_registry = { specs = specs, ordered = ordered }

---@return onebeer.PackRegistry
local function new_registry()
  return { specs = {}, ordered = {} }
end

---@generic T
---@param value T|T[]|nil
---@return T[]
local function as_list(value)
  if value == nil then
    return {}
  end
  return vim.islist(value) and value or { value }
end

---@param raw onebeer.PluginSpec
---@return string|nil
local function repo_name(raw)
  local src = raw.src or raw[1]
  return type(src) == "string" and src:match("/([^/]+)$") or nil
end

---@param name string
---@param raw onebeer.PluginSpec
---@return string
local function default_main(name, raw)
  if raw.main ~= nil then
    return raw.main
  end
  return name:gsub("%.nvim$", "")
end

---@param raw onebeer.PluginSpec
---@return onebeer.PluginVersion|nil
local function pinned_version(raw)
  return raw.version or raw.branch
end

---@param spec onebeer.PackSpec
---@return onebeer.PluginOpts|nil
local function resolve_opts(spec)
  local opts = spec.opts
  if type(opts) == "function" then
    opts = opts()
  end
  return opts
end

---@param spec onebeer.PackSpec
---@param path string
local function build_command(spec, path)
  local build = assert(spec.build, ("missing build command for %s"):format(spec.name))
  if type(build) == "function" then
    vim.cmd.packadd(vim.fn.escape(spec.name, " "))
    build(spec, path)
    return
  end

  if build:sub(1, 1) == ":" then
    vim.cmd.packadd(vim.fn.escape(spec.name, " "))
    vim.cmd(build:sub(2))
    return
  end

  local result = vim.system(vim.split(build, " ", { trimempty = true }), { cwd = path }):wait()
  if result.code ~= 0 then
    error(result.stderr ~= "" and result.stderr or ("build failed for " .. spec.name))
  end
end

---@param spec onebeer.PackSpec
local function setup(spec)
  local opts = resolve_opts(spec)

  if type(spec.config) == "function" then
    spec.config(spec, opts)
    return
  end

  if spec.config == true or opts ~= nil then
    if spec.main == nil or spec.main == "" then
      return
    end
    require(spec.main).setup(opts or {})
  end
end

---@param spec onebeer.PackSpec
local function unregister_commands(spec)
  for _, command in ipairs(as_list(spec.cmd)) do
    if command_stubs[command] then
      pcall(vim.api.nvim_del_user_command, command)
      command_stubs[command] = nil
    end
  end
end

---@param name string
local function load(name)
  if loaded[name] then
    return
  end

  local spec = assert(specs[name], ("missing spec for %s"):format(name))
  for _, dep in ipairs(spec.dependencies) do
    load(dep)
  end

  unregister_commands(spec)
  vim.cmd.packadd(vim.fn.escape(name, " "))
  loaded[name] = true
  setup(spec)
end

---@param registry onebeer.PackRegistry
---@param raw onebeer.PluginSpec
---@return string|nil
local function register_in_registry(registry, raw)
  local enabled = raw.enabled
  if enabled ~= nil and not (type(enabled) == "function" and enabled() or enabled) then
    return nil
  end

  local src = raw.src or raw[1]
  if type(src) ~= "string" then
    return nil
  end

  local name = raw.name or repo_name(raw)
  if type(name) ~= "string" or name == "" then
    return nil
  end

  ---@type onebeer.PackSpec
  local spec = registry.specs[name]
    or {
      name = name,
      dependencies = {},
      lazy = true,
      priority = 0,
      keys = {},
      main = "",
      src = "",
    }

  if registry.specs[name] == nil then
    table.insert(registry.ordered, name)
  end

  spec.src = src:match("^https?://") and src or ("https://github.com/" .. src)
  -- Preserve an earlier explicit pin when the same plugin is later referenced as an unpinned dependency.
  spec.version = pinned_version(raw) or spec.version
  spec.main = default_main(name, raw)
  spec.lazy = raw.lazy == false and false or spec.lazy
  spec.priority = raw.priority or spec.priority
  spec.event = raw.event or spec.event
  spec.ft = raw.ft or spec.ft
  spec.cmd = raw.cmd or spec.cmd
  spec.keys = raw.keys or spec.keys
  spec.init = raw.init or spec.init
  spec.opts = raw.opts or spec.opts
  spec.config = raw.config or spec.config
  spec.build = raw.build or spec.build

  registry.specs[name] = spec

  for _, dep in ipairs(as_list(raw.dependencies)) do
    local dep_name = type(dep) == "string" and register_in_registry(registry, { dep })
      or register_in_registry(registry, dep)
    if dep_name ~= nil and not vim.tbl_contains(spec.dependencies, dep_name) then
      table.insert(spec.dependencies, dep_name)
    end
  end

  return name
end

---@param registry onebeer.PackRegistry
---@param raw onebeer.PluginModule
local function register_module_in_registry(registry, raw)
  if type(raw) ~= "table" then
    return
  end

  if type(raw[1]) == "table" and raw.src == nil then
    for _, spec in ipairs(raw) do
      register_in_registry(registry, spec)
    end
    return
  end

  register_in_registry(registry, raw)
end

---@param raw onebeer.PluginModule
local function register_module(raw)
  register_module_in_registry(runtime_registry, raw)
end

---@param rhs string|fun()
local function keymap_action(rhs)
  if type(rhs) == "function" then
    rhs()
    return
  end
  vim.api.nvim_feedkeys(vim.keycode(rhs), "m", false)
end

---@param spec onebeer.PackSpec
local function register_keymaps(spec)
  for _, key in ipairs(spec.keys or {}) do
    vim.keymap.set(key.mode or "n", key[1], function()
      load(spec.name)
      keymap_action(key[2])
    end, { desc = key.desc, silent = true })
  end
end

---@param spec onebeer.PackSpec
local function register_commands(spec)
  for _, command in ipairs(as_list(spec.cmd)) do
    command_stubs[command] = spec.name
    vim.api.nvim_create_user_command(command, function(ctx)
      local prefix = ctx.range > 0 and ("%d,%d"):format(ctx.line1, ctx.line2) or ""
      local bang = ctx.bang and "!" or ""
      local args = ctx.args ~= "" and (" " .. ctx.args) or ""
      load(spec.name)
      vim.cmd(prefix .. command .. bang .. args)
    end, { bang = true, nargs = "*", range = true })
  end
end

---@param spec onebeer.PackSpec
local function register_events(spec)
  for _, event in ipairs(as_list(spec.event)) do
    local opts = {
      once = true,
      callback = function()
        load(spec.name)
      end,
    }
    if event == "VeryLazy" then
      event = "User"
      opts.pattern = "VeryLazy"
    end
    autocmds.create_autocmd(event, opts)
  end

  if spec.ft ~= nil then
    autocmds.create_autocmd("FileType", {
      pattern = as_list(spec.ft),
      once = true,
      callback = function()
        load(spec.name)
      end,
    })
  end
end

---@param items string[]
---@param lead string
---@return string[]
local function complete_matches(items, lead)
  return vim.tbl_filter(function(item)
    return vim.startswith(item, lead)
  end, items)
end

---@return string[]
local function pack_plugin_names()
  local names = {}
  for _, plugin in ipairs(vim.pack.get(nil, { info = false })) do
    names[#names + 1] = plugin.spec.name
  end
  table.sort(names)
  return names
end

---@return onebeer.PackRegistry|nil, string|nil
local function collect_registry()
  local registry = new_registry()
  for _, module in ipairs(require("onebeer.pack_modules").list()) do
    package.loaded[module] = nil
    local ok, raw = pcall(require, module)
    if not ok then
      return nil, ("Failed to load %s:\n%s"):format(module, raw)
    end
    register_module_in_registry(registry, raw)
  end
  return registry, nil
end

---@param registry onebeer.PackRegistry
---@return vim.pack.Spec[]
local function registry_pack_specs(registry)
  ---@type vim.pack.Spec[]
  local pack_specs = {}
  for _, name in ipairs(registry.ordered) do
    local spec = registry.specs[name]
    pack_specs[#pack_specs + 1] = { src = spec.src, name = spec.name, version = spec.version }
  end
  return pack_specs
end

---@param items string[]
---@return table<string, boolean>
local function name_set(items)
  local names = {}
  for _, item in ipairs(items) do
    names[item] = true
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

---@param ctx vim.api.keyset.user_command.callback_args
local function run_pack_sync(ctx)
  local registry, err = collect_registry()
  if registry == nil then
    vim.notify(err or "Failed to collect Pack plugin specs", vim.log.levels.ERROR, { title = "Pack" })
    return
  end

  local desired_names = vim.deepcopy(registry.ordered)
  local current_names = pack_plugin_names()
  local desired_set = name_set(desired_names)
  local current_set = name_set(current_names)
  local added_names = {}
  local removed_names = {}

  for _, name in ipairs(desired_names) do
    if not current_set[name] then
      added_names[#added_names + 1] = name
    end
  end
  for _, name in ipairs(current_names) do
    if not desired_set[name] then
      removed_names[#removed_names + 1] = name
    end
  end

  local ok_add, add_err = pcall(vim.pack.add, registry_pack_specs(registry), { load = false, confirm = false })
  if not ok_add then
    vim.notify(add_err, vim.log.levels.ERROR, { title = "Pack" })
    return
  end

  if #removed_names > 0 then
    local ok_del, del_err = pcall(vim.pack.del, removed_names, { force = true })
    if not ok_del then
      vim.notify(del_err, vim.log.levels.ERROR, { title = "Pack" })
      return
    end
  end

  if #added_names > 0 or #removed_names > 0 then
    local summary = {}
    if #added_names > 0 then
      summary[#summary + 1] = ("installed %d %s"):format(#added_names, pluralize(#added_names, "plugin", "plugins"))
    end
    if #removed_names > 0 then
      summary[#summary + 1] = ("removed %d %s"):format(#removed_names, pluralize(#removed_names, "plugin", "plugins"))
    end
    vim.notify(
      ("Pack sync reconciled config: %s. Restart to fully apply add/remove changes."):format(
        table.concat(summary, ", ")
      ),
      vim.log.levels.INFO,
      { title = "Pack" }
    )
  end

  if #desired_names == 0 then
    vim.notify("Pack sync complete. No configured plugins remain.", vim.log.levels.INFO, { title = "Pack" })
    return
  end

  if ctx.bang then
    vim.pack.update(desired_names, { force = true })
    return
  end

  require("onebeer.pack_review").open_update(desired_names)
end

---@param arg_lead string
---@param cmd_line string
---@return string[]
local function complete_pack(arg_lead, cmd_line)
  local args = vim.split(cmd_line, "%s+", { trimempty = true })
  if #args <= 2 then
    return complete_matches({ "sync", "update" }, arg_lead)
  end

  if args[2] == "update" then
    return complete_matches(pack_plugin_names(), arg_lead)
  end

  return {}
end

---@param ctx vim.api.keyset.user_command.callback_args
local function run_pack_command(ctx)
  local args = vim.split(vim.trim(ctx.args), "%s+", { trimempty = true })
  if args[1] == "sync" then
    if #args > 1 then
      vim.notify("Usage: :Pack[!] sync", vim.log.levels.ERROR, { title = "Pack" })
      return
    end
    run_pack_sync(ctx)
    return
  end

  if args[1] == "update" then
    local names = {}
    for i = 2, #args do
      names[#names + 1] = args[i]
    end
    names = #names > 0 and names or nil
    if ctx.bang then
      vim.pack.update(names, { force = true })
      return
    end
    require("onebeer.pack_review").open_update(names)
    return
  end

  vim.notify("Usage: :Pack[!] sync | :Pack[!] update [plugin ...]", vim.log.levels.ERROR, { title = "Pack" })
end

for _, plugin in ipairs(disabled_plugins) do
  vim.g["loaded_" .. plugin] = 1
end

for _, module in ipairs(modules) do
  ---@type onebeer.PluginModule
  local raw = require(module)
  register_module(raw)
end

autocmds.create_autocmd("PackChanged", {
  callback = function(ev)
    local spec = specs[ev.data.spec.name]
    if spec and (type(spec.build) == "string" or type(spec.build) == "function") then
      build_command(spec, ev.data.path)
    end
  end,
})

autocmds.create_command("Pack", run_pack_command, {
  bang = true,
  nargs = "+",
  complete = complete_pack,
  desc = "Run vim.pack helpers",
})

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.schedule(function()
      vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    end)
  end,
})

for _, name in ipairs(ordered) do
  local spec = specs[name]
  if spec.init then
    spec.init()
  end
end

---@type vim.pack.Spec[]
local pack_specs = {}
for _, name in ipairs(ordered) do
  local spec = specs[name]
  table.insert(pack_specs, { src = spec.src, name = spec.name, version = spec.version })
end
vim.pack.add(pack_specs, { load = false, confirm = false })

table.sort(ordered, function(a, b)
  local sa, sb = specs[a], specs[b]
  return sa.priority == sb.priority and sa.name < sb.name or sa.priority > sb.priority
end)

for _, name in ipairs(ordered) do
  local spec = specs[name]
  register_keymaps(spec)
  register_commands(spec)
  register_events(spec)
  if spec.lazy == false then
    load(name)
  end
end
