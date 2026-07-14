---@type onebeer.PluginSpec
return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    -- Adapters
    "nvim-neotest/neotest-go",
    "nvim-neotest/neotest-jest",
    "marilari88/neotest-vitest",
    "nvim-neotest/neotest-plenary",
  },
  keys = {
    {
      "<leader>tt",
      function()
        require("neotest").run.run()
      end,
      desc = "[T]est [T]est nearest",
    },
    {
      "<leader>tf",
      function()
        require("neotest").run.run(vim.fn.expand("%"))
      end,
      desc = "[T]est [F]ile",
    },
    {
      "<leader>td",
      function()
        local dap = require("onebeer.mule.integrations.dap")
        local can_debug, reason = dap.guard(vim.api.nvim_buf_get_name(0))
        if not can_debug then
          vim.notify(reason, vim.log.levels.WARN, { title = "Mule DAP" })
          return
        end
        require("neotest").run.run({ strategy = "dap" })
      end,
      desc = "[T]est [D]ebug nearest",
    },
    {
      "<leader>ts",
      function()
        require("neotest").summary.toggle()
      end,
      desc = "[T]est [S]ummary",
    },
    {
      "<leader>to",
      function()
        require("neotest").output.open({ enter = true, auto_close = true })
      end,
      desc = "[T]est [O]utput",
    },
    {
      "<leader>tO",
      function()
        require("neotest").output_panel.toggle()
      end,
      desc = "[T]est [O]utput panel",
    },
    {
      "<leader>tS",
      function()
        require("neotest").run.stop()
      end,
      desc = "[T]est [S]top",
    },
    {
      "<leader>tw",
      function()
        require("neotest").watch.toggle()
      end,
      desc = "[T]est [W]atch",
    },
  },
  config = function()
    local neotest = require("neotest")
    neotest.setup({
      adapters = {
        require("neotest-go")({
          experimental = {
            test_table = true,
          },
          args = { "-count=1", "-timeout=60s" },
        }),
        require("neotest-jest")({
          jestCommand = "npm test --",
          jestConfigFile = "jest.config.js",
          env = { CI = true },
          cwd = function()
            return vim.fn.getcwd()
          end,
        }),
        require("neotest-vitest"),
        require("neotest-plenary"),
        require("onebeer.mule.integrations.neotest").adapter(),
      },
      discovery = {
        enabled = false,
      },
      running = {
        concurrent = true,
      },
      summary = {
        open = "botright vsplit | vertical resize 50",
      },
    })
  end,
}
