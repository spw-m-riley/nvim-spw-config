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
    local js_ts_filetypes = {
      [ft.javascript] = true,
      [ft.javascriptreact] = true,
      [ft.typescript] = true,
      [ft.typescriptreact] = true,
      [ft.astro] = true,
    }
    local has_eslint_d = vim.fn.exepath("eslint_d") ~= "" and lint.linters.eslint_d ~= nil
    local js_ts_fast_linters = { "oxlint" }
    if has_eslint_d then
      table.insert(js_ts_fast_linters, "eslint_d")
    end

    lint.linters_by_ft = {
      [ft.astro] = { "eslint" },
      [ft.javascript] = { "eslint" },
      [ft.javascriptreact] = { "eslint" },
      [ft.typescript] = { "eslint" },
      [ft.typescriptreact] = { "eslint" },
      [ft.gitcommit] = { "gitlint" },
      [ft.dockerfile] = { "hadolint" },
      [ft.lua] = { "selene" },
      [ft.markdown] = { "markdownlint", "write_good", "woke" },
      [ft.sh] = { "shellcheck" },
      [ft.yaml] = { "yamllint" },
      [ft.ghactions] = { "actionlint" },
      [ft.terraform] = { "tflint" },
    }

    local lint_group = create_group("OneBeerLint")
    local function run_linters(linters)
      if linters ~= nil then
        for _, linter in ipairs(linters) do
          lint.try_lint(linter, { ignore_errors = true })
        end
        return
      end
      lint.try_lint(nil, { ignore_errors = true })
    end

    local function debounced_lint(bufnr, linters)
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
        vim.api.nvim_buf_call(bufnr, function()
          run_linters(linters)
        end)
      end, 150)
    end

    create_autocmd("InsertLeave", {
      group = lint_group,
      callback = function(args)
        local filetype = vim.bo[args.buf].filetype
        if js_ts_filetypes[filetype] then
          debounced_lint(args.buf, js_ts_fast_linters)
        end
      end,
    })

    create_autocmd("BufWritePost", {
      group = lint_group,
      callback = function(args)
        local filetype = vim.bo[args.buf].filetype
        if js_ts_filetypes[filetype] then
          debounced_lint(args.buf, { "eslint" })
          return
        end
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
