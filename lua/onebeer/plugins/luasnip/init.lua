---@module "lazy"
---@type LazySpec
return {
  "L3MON4D3/LuaSnip",
  dependencies = { "rafamadriz/friendly-snippets" },
  version = "v2.*",
  build = "make install_jsregexp",
  event = "InsertEnter",
  config = function()
    local luasnip = require("luasnip")
    local conf_dir = vim.fn.stdpath("config")

    require("luasnip.loaders.from_vscode").lazy_load()
    local types = require("luasnip.util.types")
    luasnip.config.set_config({
      history = true,
      updateevents = "TextChanged,TextChangedI",
      enable_autosnippets = true,
      ext_opts = {
        [types.choiceNode] = {
          active = {
            virt_text = { { "", "WarningMsg" } },
          },
        },
      },
    })

    require("luasnip.loaders.from_lua").load({
      paths = conf_dir .. "/lua/onebeer/snippets",
    })

    vim.keymap.set({ "i", "s" }, "<C-l>", function()
      if luasnip.choice_active() then
        luasnip.change_choice(1)
      end
    end)
    vim.keymap.set({ "i", "s" }, "<C-h>", function()
      if luasnip.choice_active() then
        luasnip.change_choice(-1)
      end
    end)
    vim.keymap.set("i", "<C-u>", require("luasnip.extras.select_choice"))
  end,
}
