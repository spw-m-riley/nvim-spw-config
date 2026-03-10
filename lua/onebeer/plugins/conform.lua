---Formatting configuration constants
local FORMAT_TIMEOUT_MS = 2000
local autocmds = require("onebeer.autocmds.helpers")
local create_command = autocmds.create_command

---@module "lazy"
---@type LazySpec
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  ---@module "conform"
  ---@type conform.setupOpts
  opts = {
    formatters_by_ft = {
      astro = { "prettierd", "prettier", "rustywind", stop_after_first = false },
      css = { "prettierd", "prettier", stop_after_first = true },
      gleam = { "gleamfmt" },
      hcl = { "hclfmt" },
      html = { "prettierd", "prettier", "rustywind", stop_after_first = false },
      go = { "goimports" },
      javascript = { "prettierd", "prettier", stop_after_first = true },
      javascriptreact = { "prettierd", "prettier", "rustywind", stop_after_first = false },
      json = { "prettierd", "prettier", stop_after_first = true },
      lua = { "stylua" },
      markdown = { "prettierd", "prettier", stop_after_first = true },
      rust = { "rustfmt" },
      sh = { "shfmt", "beautysh", stop_after_first = true },
      sql = { "sqlfluff" },
      svelte = { "prettierd", "prettier", stop_after_first = true },
      templ = { "templ" },
      typescript = { "prettierd", "prettier", stop_after_first = true },
      typescriptreact = { "prettierd", "prettier", "rustywind", stop_after_first = false },
      yaml = { "prettierd", "prettier", stop_after_first = true },
      zsh = { "shfmt", "beautysh", stop_after_first = true },
    },
    default_format_opts = {
      lsp_format = "fallback",
    },
    format_on_save = function(bufnr)
      local buf = bufnr or 0
      if vim.g.disable_autoformat or vim.b[buf].disable_autoformat then
        return
      end
      return {
        lsp_format = "fallback",
        timeout_ms = FORMAT_TIMEOUT_MS,
        async = false,
      }
    end,
    formatters = {
      templ = {
        command = "templ",
        args = { "fmt", "$FILENAME" },
        stdin = false,
      },
    },
  },
  init = function()
    create_command("FormatToggle", function()
      vim.g.disable_autoformat = not vim.g.disable_autoformat
      local status = vim.g.disable_autoformat and "disabled" or "enabled"
      vim.notify("Format on save " .. status, vim.log.levels.INFO)
    end, { desc = "Toggle format on save" })

    create_command("FormatToggleBuffer", function()
      local disabled = vim.b.disable_autoformat == true
      vim.b.disable_autoformat = not disabled
      local status = vim.b.disable_autoformat and "disabled" or "enabled"
      vim.notify("Format on save " .. status .. " for buffer", vim.log.levels.INFO)
    end, { desc = "Toggle format on save (buffer)" })
  end,
}
