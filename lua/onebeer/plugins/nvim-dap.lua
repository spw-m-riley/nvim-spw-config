---@type onebeer.PluginSpec
return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "nvim-neotest/nvim-nio",
    "theHamsta/nvim-dap-virtual-text",
    {
      "leoluz/nvim-dap-go",
      ft = { "go", "gomod", "templ" },
      opts = {},
      config = function(_, opts)
        local lsp_settings = require("onebeer.settings.lsp")
        local delve = lsp_settings.resolve_executable("dlv")
        if delve then
          opts = vim.tbl_deep_extend("force", opts or {}, { delve = { path = delve } })
          require("dap-go").setup(opts)
        end
      end,
    },
  },
  event = "VeryLazy",
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")
    require("nvim-dap-virtual-text")
    local utils = require("dap.utils")

    dap.set_log_level("WARN")

    local lsp_settings = require("onebeer.settings.lsp")
    local js_debug_adapter = lsp_settings.resolve_executable("js-debug-adapter")
    if js_debug_adapter then
      dap.adapters["pwa-node"] = {
        type = "server",
        host = "::1",
        port = "${port}",
        executable = {
          command = js_debug_adapter,
          args = { "${port}" },
        },
      }

      for _, language in ipairs({ "typescript", "typescriptreact", "javascript", "javascriptreact" }) do
        dap.configurations[language] = {
          {
            type = "pwa-node",
            request = "launch",
            name = "Launch File",
            program = "${file}",
            cwd = "${workspaceFolder}",
          },
          {
            type = "pwa-node",
            request = "attach",
            name = "Attach to process ID",
            processId = utils.pick_process,
            cwd = "${workspaceFolder}",
          },
        }
      end
    end

    local ok_mule_dap, mule_dap = pcall(require, "onebeer.mule.integrations.dap")
    if ok_mule_dap then
      mule_dap.setup()
    end

    dapui.setup({
      icons = { expanded = "▾", collapsed = "▸", current_frame = "*" },
      controls = {
        icons = {
          pause = "⏸",
          play = "▶",
          step_into = "⏎",
          step_over = "⏭",
          step_out = "⏮",
          step_back = "b",
          run_last = "▶▶",
          terminate = "⏹",
          disconnect = "⏏",
        },
      },
    })

    dap.listeners.after.event_initialized["dapui_config"] = dapui.open
    dap.listeners.before.event_terminated["dapui_config"] = dapui.close
    dap.listeners.before.event_exited["dapui_config"] = dapui.close

    require("nvim-dap-virtual-text").setup()
  end,
  keys = {
    { "<leader>ds", "<cmd>DapContinue<cr>", desc = "[s]tart/continue" },
    { "<leader>di", "<cmd>DapStepInto<cr>", desc = "Step [i]nto" },
    { "<leader>do", "<cmd>DapStepOut<cr>", desc = "Step [o]ut" },
    { "<leader>dv", "<cmd>DapStepOver<cr>", desc = "Step o[v]er" },
    { "<leader>db", "<cmd>DapToggleBreakpoint<cr>", desc = "Toggle [b]reakpoint" },
    { "<leader>du", "<cmd>DapUiToggle<cr>", desc = "UI [t]oggle" },
    {
      "<leader>dg",
      function()
        local ok, dapgo = pcall(require, "dap-go")
        if not ok then
          vim.notify("dap-go is not available", vim.log.levels.WARN, { title = "nvim-dap" })
          return
        end
        dapgo.debug_test()
      end,
      desc = "Debug Go test",
    },
  },
}
