local headers = require("onebeer.plugins.starter.headers")
local ui = require("onebeer.ui")
local STATUSCOL_EXPR = "%!v:lua.require'snacks.statuscolumn'.get()"

---@module "lazy"
---@type LazySpec
return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    bigfile = { enabled = true },
    dashboard = {
      enabled = true,
      preset = {
        header = headers.DOOM,
        keys = {
          { icon = " ", key = "f", desc = "Find File", action = "<leader>sf" },
          { icon = " ", key = "g", desc = "Live Grep", action = "<leader>sg" },
          { icon = " ", key = "r", desc = "Recent Files", action = "<leader>sr" },
          { icon = " ", key = "b", desc = "Buffers", action = "<leader>sb" },
          {
            icon = " ",
            key = "c",
            desc = "Edit Config",
            action = ":lua Snacks.dashboard.pick('files', { cwd = vim.fn.stdpath('config') })",
          },
        },
      },
      sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        {
          icon = " ",
          title = "Recent Files",
          section = "recent_files",
          cwd = true,
          filter = function(file)
            return not file:find("COMMIT_EDITMSG", 1, true)
          end,
          indent = 2,
          padding = 1,
        },
        {
          icon = " ",
          title = "Projects",
          section = "projects",
          indent = 2,
          padding = 1,
        },
        {
          icon = "󰁯 ",
          title = "Sessions",
          section = "session",
          indent = 2,
          padding = 1,
        },
        { section = "startup" },
      },
    },
    quickfile = {
      enabled = true,
    },
    styles = {
      notification = ui.snacks_float_style(nil, "notification"),
      notification_history = ui.snacks_float_style(),
    },
    indent = {
      enabled = true,
      only_current = false,
      scope = {
        enabled = true,
        underline = false,
      },
      animate = {
        enabled = vim.fn.has("nvim-0.10") == 1,
      },
    },
    notifier = {
      enabled = true,
      timeout = 2000,
      top_down = false,
      style = "compact",
      margin = { top = 0, right = 1, bottom = 0 },
    },
    scroll = {
      enabled = false,
    },
    statuscolumn = {
      enabled = true,
    },
    scope = {
      enabled = true,
      edge = true,
      siblings = true,
      underline = true,
      keys = {
        textobject = {
          ii = {
            desc = "inner scope",
            edge = false,
            cursor = false,
            min_size = 2,
          },
          ai = {
            desc = "outer scope",
            cursor = false,
            min_size = 2,
          },
        },
        jump = {
          ["[i"] = { desc = "Prev scope edge", bottom = false, min_size = 1 },
          ["]i"] = { desc = "Next scope edge", bottom = true, min_size = 1 },
        },
      },
    },
    words = {
      enabled = true,
      notify_jump = false,
      notify_end = false,
    },
  },
  keys = {
    {
      "]r",
      function()
        require("snacks").words.jump(1, true)
      end,
      desc = "Next reference",
    },
    {
      "[r",
      function()
        require("snacks").words.jump(-1, true)
      end,
      desc = "Prev reference",
    },
    {
      "<leader>sd",
      function()
        require("snacks").dashboard.open()
      end,
      desc = "[S]nacks [D]ashboard",
    },
    {
      "<leader>vg",
      function()
        require("snacks").gitbrowse()
      end,
      desc = "[V]CS [G]it browse",
    },
    {
      "<leader>vB",
      function()
        require("snacks").git.blame_line({ count = 5 })
      end,
      desc = "[V]CS [B]lame line",
    },
    {
      "<leader>un",
      function()
        require("snacks").notifier.show_history()
      end,
      desc = "[U]I [N]otifications",
    },
    {
      "<leader>uw",
      function()
        local words = require("snacks").words
        if words.is_enabled({ modes = true }) then
          words.disable()
          vim.notify("Snacks words disabled")
        else
          words.enable()
          vim.notify("Snacks words enabled")
        end
      end,
      desc = "[U]I toggle [W]ords",
    },
    {
      "<leader>uv",
      function()
        local config = vim.diagnostic.config()
        local vt = config.virtual_text
        local enabled = vt ~= false
        vim.diagnostic.config({
          virtual_text = enabled and false or { prefix = "", spacing = 2, source = "if_many" },
          virtual_lines = enabled and { current_line = true } or false,
        })
        vim.notify(("Diagnostic virtual text %s"):format(enabled and "disabled" or "enabled"))
      end,
      desc = "[U]I toggle [V]irtual text",
    },
    {
      "<leader>us",
      function()
        local enabled = vim.o.statuscolumn ~= ""
        if enabled then
          vim.g.onebeer_statuscolumn_manual_off = true
          vim.o.statuscolumn = ""
        else
          vim.g.onebeer_statuscolumn_manual_off = false
          vim.o.statuscolumn = vim.g.onebeer_statuscolumn_expr or STATUSCOL_EXPR
        end
        vim.g.onebeer_statuscolumn_cached = vim.o.statuscolumn ~= "" and vim.o.statuscolumn
          or vim.g.onebeer_statuscolumn_cached
        vim.notify(("Statuscolumn %s"):format(enabled and "hidden" or "shown"))
      end,
      desc = "[U]I toggle [S]tatuscolumn",
    },
    {
      "<leader>uS",
      function()
        local scroll = require("snacks").scroll
        if scroll.enabled then
          scroll.disable()
          vim.notify("Snacks smooth scroll disabled")
        else
          scroll.enable()
          vim.notify("Snacks smooth scroll enabled")
        end
      end,
      desc = "[U]I toggle smooth [S]croll",
    },
  },
  config = function(_, opts)
    vim.g.onebeer_statuscolumn_expr = STATUSCOL_EXPR
    if vim.o.statuscolumn == "" then
      vim.o.statuscolumn = STATUSCOL_EXPR
    end
    vim.g.onebeer_statuscolumn_cached = vim.o.statuscolumn
    vim.g.onebeer_statuscolumn_manual_off = false
    require("snacks").setup(opts)
  end,
}
