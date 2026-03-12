---@module "lazy"
---@type LazySpec
return {
  "mason-org/mason-lspconfig.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    automatic_enable = false,
    ensure_installed = {
      "astro",
      "bashls",
      "gopls",
      "gh_actions_ls",
      "html",
      "jsonls",
      "yamlls",
      "terraformls",
      "lua_ls",
      "ts_ls",
    },
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
    local lsp_settings = require("onebeer.settings.lsp")

    require("mason-lspconfig").setup(opts)

    local function enable(server, predicate)
      if predicate() then
        vim.lsp.enable(server)
      end
    end

    enable("actionsls", function()
      return lsp_settings.has_any_executable({
        "actions-languageserver",
        "gh-actions-language-server",
        "actions-language-server",
      })
    end)
    enable("gleam", function()
      return vim.fn.exepath("gleam") ~= ""
    end)
    enable("gopls", function()
      return vim.fn.exepath("gopls") ~= ""
    end)
    enable("html", function()
      return vim.fn.exepath("vscode-html-language-server") ~= ""
    end)
    enable("terraformls", function()
      return vim.fn.exepath("terraform-ls") ~= ""
    end)
    enable("lua_ls", function()
      return lsp_settings.is_executable("lua-language-server")
    end)
    enable("ts_ls", function()
      return vim.fn.exepath("typescript-language-server") ~= ""
    end)
    enable("jsonls", function()
      return vim.fn.exepath("vscode-json-language-server") ~= ""
    end)
    enable("yamlls", function()
      return lsp_settings.is_executable("yaml-language-server")
    end)
    enable("bashls", function()
      return vim.fn.exepath("bash-language-server") ~= ""
    end)
    enable("astro", function()
      return vim.fn.exepath("astro-ls") ~= ""
    end)
  end,
}
