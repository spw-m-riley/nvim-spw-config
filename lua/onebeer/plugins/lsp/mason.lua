---@module "lazy"
---@type LazySpec
local lsp_settings = require("onebeer.settings.lsp")

local actions_server_cmd_candidates = {
  "actions-languageserver",
  "gh-actions-language-server",
  "actions-language-server",
}

-- Repo-root lsp/*.lua files own per-server config. Keep this registry limited
-- to package names plus availability checks so later language tracks can add
-- shared-surface entries in one place without moving config ownership.
local servers = {
  {
    name = "actionsls",
    package = "gh_actions_ls",
    is_available = function()
      return lsp_settings.resolve_executable(actions_server_cmd_candidates) ~= nil
    end,
  },
  {
    name = "astro",
    package = "astro",
    is_available = function()
      return lsp_settings.is_executable("astro-ls")
    end,
  },
  {
    name = "bashls",
    package = "bashls",
    is_available = function()
      return lsp_settings.is_executable("bash-language-server")
    end,
  },
  {
    name = "gleam",
    is_available = function()
      return lsp_settings.is_executable("gleam")
    end,
  },
  {
    name = "gopls",
    package = "gopls",
    is_available = function()
      return lsp_settings.is_executable("gopls")
    end,
  },
  {
    name = "html",
    package = "html",
    is_available = function()
      return lsp_settings.is_executable("vscode-html-language-server")
    end,
  },
  {
    name = "jsonls",
    package = "jsonls",
    is_available = function()
      return lsp_settings.is_executable("vscode-json-language-server")
    end,
  },
  {
    name = "lua_ls",
    package = "lua_ls",
    is_available = function()
      return lsp_settings.is_executable("lua-language-server")
    end,
  },
  {
    name = "pyright",
    package = "pyright",
    is_available = function()
      return lsp_settings.is_executable("pyright-langserver")
    end,
  },
  {
    name = "ruff",
    package = "ruff",
    is_available = function()
      return lsp_settings.is_executable("ruff")
    end,
  },
  {
    name = "ruby_lsp",
    is_available = function()
      return vim.fn.exepath("ruby-lsp") ~= ""
    end,
  },
  {
    name = "rust_analyzer",
    package = "rust-analyzer",
    is_available = function()
      return lsp_settings.is_executable("rust-analyzer")
    end,
  },
  {
    name = "terraformls",
    package = "terraformls",
    is_available = function()
      return lsp_settings.is_executable("terraform-ls")
    end,
  },
  {
    name = "ts_ls",
    package = "ts_ls",
    is_available = function()
      return lsp_settings.is_executable("typescript-language-server")
    end,
  },
  {
    name = "yamlls",
    package = "yamlls",
    is_available = function()
      return lsp_settings.is_executable("yaml-language-server")
    end,
  },
  {
    name = "zls",
    package = "zls",
    is_available = function()
      return lsp_settings.is_executable("zls")
    end,
  },
}

local function mason_packages()
  local packages = {}

  for _, server in ipairs(servers) do
    if server.package then
      table.insert(packages, server.package)
    end
  end

  return packages
end

return {
  "mason-org/mason-lspconfig.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
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
      config = true,
    },
    "neovim/nvim-lspconfig",
  },
  config = function(_, opts)
    require("mason-lspconfig").setup(vim.tbl_deep_extend("force", opts, {
      ensure_installed = mason_packages(),
    }))

    for _, server in ipairs(servers) do
      if server.is_available() then
        vim.lsp.enable(server.name)
      end
    end
  end,
}
