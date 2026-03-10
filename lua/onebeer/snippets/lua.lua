local ls = require("luasnip")
local s = ls.s
local i = ls.i
local t = ls.t

-- local d = ls.dynamic_node
-- local f = ls.function_node

local fmt = require("luasnip.extras.fmt").fmt
local rep = require("luasnip.extras").rep

---@alias LuaSnipSnippet any

---@type LuaSnipSnippet[]
local snippets = {}

local preq = s({
  trig = "preq",
  name = "pcall require",
  dscr = "Adds a pcall for require and also adds the if statement to safely return if the dependency is not met",
}, {
  t("local has_"),
  i(1),
  t(", "),
  rep(1),
  t(" = pcall(require, '"),
  rep(1),
  t({ "')", "", "if not has_" }),
  rep(1),
  t({ " then", "\treturn", "end" }),
})

-- Neovim plugin configuration pattern
local nvim = s(
  {
    trig = "nvim",
    name = "Neovim plugin config",
    dscr = "Neovim plugin config pattern",
  },
  fmt(
    [[
    local {} = require('{}')
    
    {}.setup({{
      {}
    }})
  ]],
    { i(1, "plugin"), i(2), rep(1), i(0) }
  )
)

-- Lazy spec definition
local lazy = s(
  {
    trig = "lazy",
    name = "Lazy.nvim spec",
    dscr = "Lazy.nvim spec definition",
  },
  fmt(
    [[
    return {{
      "{}",
      event = "{}",
      opts = {{
        {}
      }},
      config = function(_, opts)
        {}
      end,
    }}
  ]],
    { i(1, "plugin.name"), i(2, "VeryLazy"), i(3), i(0) }
  )
)

-- Conditional require with pcall
local creq = s(
  {
    trig = "creq",
    name = "Conditional require",
    dscr = "Conditional require with pcall",
  },
  fmt(
    [[
    local ok, {} = pcall(require, '{}')
    if not ok then
      return
    end
  ]],
    { i(1), i(2) }
  )
)

table.insert(snippets, preq)
table.insert(snippets, nvim)
table.insert(snippets, lazy)
table.insert(snippets, creq)
return snippets
