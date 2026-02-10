---@module "lazy"
---@type LazySpec
return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local autocmds = require("onebeer.autocmds.helpers")
    local create_group = autocmds.create_group
    local create_autocmd = autocmds.create_autocmd
    local create_command = autocmds.create_command
    local ft = require("onebeer.settings.filetypes")
    local lint = require("lint")

    lint.linters_by_ft = {
      [ft.astro] = { "oxlint" },
      [ft.javascript] = { "eslint", "oxlint" },
      [ft.typescript] = { "eslint", "oxlint" },
      [ft.typescriptreact] = { "eslint", "oxlint" },
      [ft.gitcommit] = { "gitlint" },
      [ft.dockerfile] = { "hadolint" },
      [ft.lua] = { "selene" },
      [ft.markdown] = { "markdownlint", "write_good", "woke" },
      [ft.sh] = { "shellcheck" },
      [ft.yaml] = { "yamllint" },
    }

    local lint_group = create_group("OneBeerLint")
    local function debounced_lint(bufnr)
      vim.defer_fn(function()
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end
        if vim.g.disable_lint or vim.b[bufnr].disable_lint then
          return
        end
        if vim.bo[bufnr].filetype == ft.go then
          return
        end
        lint.try_lint(nil, { ignore_errors = true })
      end, 150)
    end

    create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
      group = lint_group,
      callback = function(args)
        debounced_lint(args.buf)
      end,
    })

    vim.keymap.set("n", "<leader>cL", function()
      lint.try_lint(nil, { ignore_errors = true })
    end, { desc = "[C]ode [L]int buffer" })

    create_command("LintToggle", function()
      local disabled = vim.g.disable_lint == true
      vim.g.disable_lint = not disabled
      local status = vim.g.disable_lint and "disabled" or "enabled"
      vim.notify("Linting " .. status, vim.log.levels.INFO)
    end, { desc = "Toggle linting (global)" })

    create_command("LintToggleBuffer", function()
      local disabled = vim.b.disable_lint == true
      vim.b.disable_lint = not disabled
      local status = vim.b.disable_lint and "disabled" or "enabled"
      vim.notify("Linting " .. status .. " for buffer", vim.log.levels.INFO)
    end, { desc = "Toggle linting (buffer)" })
  end,
}
