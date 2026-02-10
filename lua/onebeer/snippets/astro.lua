local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local t = ls.text_node
local fmt = require("luasnip.extras.fmt").fmt

return {
  -- Astro component with props
  s(
    { trig = "astro", dscr = "Astro component with props" },
    fmt(
      [[
        ---
        interface Props {
          [name]: string;
        }

        const { [name] } = Astro.props;
        ---

        <div>
          <h1>[name]</h1>
          [content]
        </div>
      ]],
      { name = i(1, "title"), content = i(0) },
      { delimiters = "[]" }
    )
  ),
  
  -- Astro layout
  s(
    { trig = "layout", dscr = "Astro layout component" },
    fmt(
      [[
        ---
        interface Props {
          title?: string;
        }
        
        const { title = "My Site" } = Astro.props;
        ---
        
        <html lang="en">
          <head>
            <meta charset="utf-8" />
            <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
            <meta name="viewport" content="width=device-width" />
            <title>{title}</title>
          </head>
          <body>
            <slot />
          </body>
        </html>
      ]],
      {},
      { delimiters = "[]" }
    )
  ),
  
  -- Astro frontmatter
  s(
    { trig = "front", dscr = "Astro frontmatter" },
    t({
      "---",
      "export interface Props {",
      "  title: string;",
      "  description?: string;",
      "  pubDate?: Date;",
      "}",
      "",
      "const { title, description, pubDate } = Astro.props;",
      "---",
      "",
    })
  ),
}