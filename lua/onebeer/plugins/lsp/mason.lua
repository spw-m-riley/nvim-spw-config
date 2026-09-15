---@type onebeer.PluginSpec
local lsp_settings = require("onebeer.settings.lsp")

local actions_server_cmd_candidates = {
  "actions-languageserver",
  "gh-actions-language-server",
  "actions-language-server",
}

---@class OneBeerLspServer
---@field config string Neovim LSP configuration name
---@field package string? Mason package name
---@field executable string|string[] Runtime executable name(s)
---@field filetypes string[]
---@field runtime_owned boolean
---@field runtime_available fun(): boolean|nil
local servers = {
  {
    config = "actionsls",
    package = "gh-actions-language-server",
    executable = actions_server_cmd_candidates,
    filetypes = { "yaml", "yaml.ghactions" },
  },
  {
    config = "astro",
    package = "astro-language-server",
    executable = "astro-ls",
    filetypes = { "astro" },
  },
  {
    config = "bashls",
    package = "bash-language-server",
    executable = "bash-language-server",
    filetypes = { "sh", "bash", "zsh" },
  },
  {
    config = "gleam",
    executable = "gleam",
    filetypes = { "gleam" },
    runtime_owned = true,
    runtime_available = function()
      return lsp_settings.is_executable("gleam")
    end,
  },
  {
    config = "gopls",
    package = "gopls",
    executable = "gopls",
    filetypes = { "go", "gomod", "gowork", "gotmpl" },
  },
  {
    config = "html",
    package = "html-lsp",
    executable = "vscode-html-language-server",
    filetypes = { "html" },
  },
  {
    config = "jsonls",
    package = "json-lsp",
    executable = "vscode-json-language-server",
    filetypes = { "json", "jsonc" },
  },
  {
    config = "lemminx",
    package = "lemminx",
    executable = "lemminx",
    filetypes = { "xml", "xsd", "xsl", "xslt", "svg" },
  },
  {
    config = "lua_ls",
    package = "lua-language-server",
    executable = "lua-language-server",
    filetypes = { "lua" },
  },
  {
    config = "pyright",
    package = "pyright",
    executable = "pyright-langserver",
    filetypes = { "python" },
  },
  {
    config = "ruff",
    executable = "ruff",
    filetypes = { "python" },
    runtime_owned = true,
    runtime_available = function()
      return lsp_settings.is_executable("ruff")
    end,
  },
  {
    config = "ruby_lsp",
    executable = "ruby-lsp",
    filetypes = { "ruby", "eruby" },
    runtime_owned = true,
  },
  {
    config = "rust_analyzer",
    package = "rust-analyzer",
    executable = "rust-analyzer",
    filetypes = { "rust" },
  },
  {
    config = "svelte",
    package = "svelte-language-server",
    executable = "svelteserver",
    filetypes = { "svelte" },
  },
  {
    config = "taplo",
    package = "taplo",
    executable = "taplo",
    filetypes = { "toml" },
  },
  {
    config = "terraformls",
    package = "terraform-ls",
    executable = "terraform-ls",
    filetypes = { "terraform", "terraform-vars" },
  },
  {
    config = "ts_ls",
    package = "typescript-language-server",
    executable = "typescript-language-server",
    filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  },
  {
    config = "yamlls",
    package = "yaml-language-server",
    executable = "yaml-language-server",
    filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab", "yaml.helm-values" },
  },
  {
    config = "zls",
    package = "zls",
    executable = "zls",
    filetypes = { "zig", "zir" },
  },
}

local servers_by_filetype = {}
local servers_by_package = {}

for _, server in ipairs(servers) do
  for _, filetype in ipairs(server.filetypes) do
    servers_by_filetype[filetype] = servers_by_filetype[filetype] or {}
    table.insert(servers_by_filetype[filetype], server)
  end

  if server.package then
    servers_by_package[server.package] = server
  end
end

local function is_available(server)
  if server.runtime_owned then
    if server.runtime_available then
      return server.runtime_available()
    end

    -- Ruby LSP must stay inside the active Ruby environment, never Mason.
    return vim.fn.exepath(server.executable) ~= ""
  end

  return lsp_settings.resolve_executable(server.executable) ~= nil
end

local function notify(message, level)
  vim.notify(("[onebeer] %s"):format(message), level)
end

return {
  "mason-org/mason-lspconfig.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    -- Server configuration remains owned by the repo-root lsp/*.lua files.
    automatic_enable = false,
  },
  dependencies = {
    {
      "mason-org/mason.nvim",
      opts = {
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          },
        },
      },
      cmd = { "Mason" },
    },
    {
      "antosha417/nvim-lsp-file-operations",
      config = function()
        require("lsp-file-operations").setup()
      end,
    },
    "neovim/nvim-lspconfig",
  },
  config = function(_, opts)
    local mason_lspconfig = require("mason-lspconfig")
    local registry = require("mason-registry")

    local pending = {}
    local waiting_for_registry = {}
    local warned_runtime = {}
    local install_server

    -- vim.lsp.config() calls have higher precedence than every lsp/*.lua file.
    -- Keep this here so nvim-lspconfig's bashls defaults cannot drop zsh.
    vim.lsp.config("bashls", { filetypes = { "sh", "bash", "zsh" } })

    local function enable_server(server)
      vim.lsp.enable(server.config)
    end

    registry:on("update:success", function()
      vim.schedule(function()
        local waiting = waiting_for_registry
        waiting_for_registry = {}
        for _, server in pairs(waiting) do
          install_server(server)
        end
      end)
    end)

    mason_lspconfig.setup(opts)

    local function on_install_success(package)
      local server = servers_by_package[package.name]
      if not server then
        return
      end

      vim.schedule(function()
        notify(("Mason installed %s; enabling %s"):format(package.name, server.config), vim.log.levels.INFO)
        -- Enabling also checks existing buffers, so the server can attach in this session.
        enable_server(server)
      end)
    end

    registry:on("package:install:success", on_install_success)

    install_server = function(server)
      if not server.package or pending[server.package] then
        return
      end

      local ok, package = pcall(registry.get_package, server.package)
      if not ok then
        waiting_for_registry[server.package] = server
        notify(("Waiting for the Mason registry before installing %s"):format(server.package), vim.log.levels.INFO)
        return
      end

      if package:is_installed() then
        enable_server(server)
        return
      end

      if package:is_installing() then
        pending[server.package] = true
        return
      end

      pending[server.package] = true
      notify(("Installing Mason package %s for %s"):format(server.package, server.config), vim.log.levels.INFO)

      local callback = vim.schedule_wrap(function(success, result)
        pending[server.package] = nil
        if not success then
          notify(("Failed to install %s: %s"):format(server.package, tostring(result)), vim.log.levels.ERROR)
        end
      end)

      local install_ok, install_error = pcall(function()
        package:install({}, callback)
      end)
      if not install_ok then
        pending[server.package] = nil
        notify(
          ("Could not start Mason installation for %s: %s"):format(server.package, tostring(install_error)),
          vim.log.levels.ERROR
        )
      end
    end

    local group = vim.api.nvim_create_augroup("OneBeerLspMason", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      callback = function(args)
        for _, server in ipairs(servers_by_filetype[vim.bo[args.buf].filetype] or {}) do
          if is_available(server) then
            enable_server(server)
          elseif server.runtime_owned then
            if not warned_runtime[server.config] then
              warned_runtime[server.config] = true
              notify(("%s is runtime-managed but is not available"):format(server.config), vim.log.levels.WARN)
            end
          else
            install_server(server)
          end
        end
      end,
    })
  end,
}
