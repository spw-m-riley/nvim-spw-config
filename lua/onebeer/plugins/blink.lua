---@module "lazy"
---@type LazySpec
local config = require("onebeer.config")

return {
  "saghen/blink.cmp",
  event = "InsertEnter",
  dependencies = {
    { "L3MON4D3/LuaSnip", version = "v2.*", build = "make install_jsregexp" },
    { "giuxtaposition/blink-cmp-copilot" },
    { "rafamadriz/friendly-snippets" },
    { "saghen/blink.compat", version = "*", opts = {} },
  },
  version = "v0.*",
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    enabled = function()
      local ft = vim.bo.filetype
      return ft ~= "minifiles" and ft ~= "minifiles-help"
    end,
    fuzzy = {
      implementation = "rust",
    },
    completion = {
      trigger = {
        prefetch_on_insert = true,
      },
      menu = {
        border = "rounded",
        winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
        draw = {
          columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source_name" } },
          treesitter = {},
        },
      },
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 100,
        window = {
          border = "rounded",
          winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
        },
      },
      ghost_text = {
        enabled = config.copilot,
      },
    },
    keymap = {
      preset = "default",
      ["<Up>"] = { "select_prev", "fallback" },
      ["<Down>"] = { "select_next", "fallback" },
      ["<Tab>"] = {
        "snippet_forward",
        function()
          return require("sidekick").nes_jump_or_apply()
        end,
        function()
          local ic = vim.lsp and vim.lsp.inline_completion
          return ic and ic.get and ic.get() or false
        end,
        "fallback",
      },
      ["<C-k>"] = { "show_documentation", "fallback" },
    },
    appearance = {
      use_nvim_cmp_as_default = true,
      nerd_font_variant = "mono",
    },
    sources = {
      providers = {
        copilot = {
          name = "copilot",
          module = "blink-cmp-copilot",
          enabled = config.copilot,
          score_offset = 60,
        },
        -- tabnine = {
        --   name = "cmp_tabnine",
        --   module = "blink.compat.source",
        --   enabled = vim.g.onebeer.copilot,
        --   score_offset = 30,
        -- },
        lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
      },
      default = { "lsp", "copilot", "path", "snippets", "buffer", "lazydev" },
    },
    snippets = {
      preset = "luasnip",
      expand = function(snippet)
        require("luasnip").lsp_expand(snippet)
      end,
      active = function(filter)
        if filter and filter.direction then
          return require("luasnip").jumpable(filter.direction)
        end
        return require("luasnip").in_snippet()
      end,
      jump = function(direction)
        require("luasnip").jump(direction)
      end,
    },
  },
  opts_extend = { "sources.default" },
}
