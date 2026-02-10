local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local d = ls.dynamic_node
local fmt = require("luasnip.extras.fmt").fmt
local fmta = require("luasnip.extras.fmt").fmta
local rep = require("luasnip.extras").rep

return {
  s(
    { trig = "echk", dscr = "Expands 'echk' to do the standard err check" },
    fmt(
      [[
        {}, err := {}({})
        if err != nil {{
          {}
        }}
      ]],
      { i(1), i(2), i(3), i(4) }
    )
  ),
  
  -- HTTP handler pattern
  s(
    { trig = "handler", dscr = "HTTP handler function" },
    fmt(
      [[
        func {}Handler(w http.ResponseWriter, r *http.Request) {{
          {}
        }}
      ]],
      { i(1, "example"), i(0) }
    )
  ),
  
  -- Struct with json tags
  s(
    { trig = "struct", dscr = "Go struct with json tags" },
    fmt(
      [[
        type {} struct {{
          {} string `json:"{}"`
        }}
      ]],
      { i(1, "Name"), i(2, "Field"), rep(2) }
    )
  ),
  
  -- Interface definition
  s(
    { trig = "iface", dscr = "Interface definition" },
    fmt(
      [[
        type {} interface {{
          {}
        }}
      ]],
      { i(1), i(0) }
    )
  ),
  
  -- Goroutine pattern
  s(
    { trig = "go", dscr = "Goroutine with waitgroup" },
    fmt(
      [[
        go func() {{
          defer wg.Done()
          {}
        }}()
      ]],
      { i(0) }
    )
  ),
  
  -- Testing table-driven tests
  s(
    { trig = "tabletest", dscr = "Table-driven test pattern" },
    fmt(
      [[
        func Test{}(t *testing.T) {{
          tests := []struct {{
            name  string
            input {}
            want  {}
          }}{{
            {{"{}", {}, {}}},
          }}
          
          for _, tt := range tests {{
            t.Run(tt.name, func(t *testing.T) {{
              got := {}({})
              if got != tt.want {{
                t.Errorf("got %v, want %v", got, tt.want)
              }}
            }})
          }}
        }}
      ]],
      { i(1), i(2), i(3), i(4), i(5), i(6), i(7), i(8) }
    )
  ),
  
  -- Benchmark test
  s(
    { trig = "bench", dscr = "Benchmark test" },
    fmt(
      [[
        func Benchmark{}(b *testing.B) {{
          for i := 0; i < b.N; i++ {{
            {}({})
          }}
        }}
      ]],
      { i(1), i(2), i(3) }
    )
  ),
}
