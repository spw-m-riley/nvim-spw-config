---@type onebeer.PluginSpec
local config = require("onebeer.config")

return {
  "saghen/blink.cmp",
  event = { "BufReadPre", "BufNewFile" },
  build = "cargo build --release",
  dependencies = {
    { "L3MON4D3/LuaSnip", branch = "master", build = "make install_jsregexp" },
    { "giuxtaposition/blink-cmp-copilot" },
    { "rafamadriz/friendly-snippets" },
    { "saghen/blink.compat", branch = "main", opts = {} },
  },
  version = "v0.*",
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = function()
    local blink = require("blink.cmp")
    local lsp_settings = require("onebeer.settings.lsp")

    local function sidekick_nes_jump_or_apply()
      if not config.copilot then
        return false
      end

      local ok, sidekick = pcall(require, "sidekick")
      return ok and sidekick.nes_jump_or_apply() or false
    end

    local function accept_inline_completion()
      local inline_completion = vim.lsp and vim.lsp.inline_completion
      if not inline_completion or type(inline_completion.get) ~= "function" then
        return false
      end

      return inline_completion.get() or false
    end

    vim.lsp.config("*", {
      capabilities = blink.get_lsp_capabilities(vim.deepcopy(lsp_settings.base_capabilities)),
    })

    return {
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
          sidekick_nes_jump_or_apply,
          accept_inline_completion,
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
            module = "onebeer.blink.copilot",
            enabled = config.copilot,
            score_offset = 60,
          },
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
    }
  end,
  opts_extend = { "sources.default" },
}
