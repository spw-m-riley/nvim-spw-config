---@module "lazy"
---@type LazySpec
return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  opts = {
    check_ts = true,                     -- Enable treesitter integration
    ts_config = {
      lua = { "string" },                -- Don't add pairs in lua string treesitter nodes
      javascript = { "template_string" },
      java = false,                      -- Don't check treesitter on java
    },
    disable_filetype = { "TelescopePrompt", "vim" },
    fast_wrap = {
      map = "<M-e>",
      chars = { "{", "[", "(", '"', "'" },
      pattern = [=[[%'%"%>%]%)%}%,]]=],
      end_key = "$",
      keys = "qwertyuiopzxcvbnmasdfghjkl",
      check_comma = true,
      highlight = "Search",
      highlight_grey = "Comment",
    },
  },
  config = function(_, opts)
    local autopairs = require("nvim-autopairs")
    autopairs.setup(opts)

    -- Integration with blink.cmp
    local ok, blink = pcall(require, "blink.cmp")
    if ok then
      autopairs.setup({
        check_ts = opts.check_ts,
        ts_config = opts.ts_config,
      })
    end
  end,
}
