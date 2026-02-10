---@module "lazy"
---@type LazySpec
return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 1000,
  opts = {
    transparent_background = true,
    flavour = "mocha",
    custom_highlights = function(colors)
      return {
        -- Blink completion ghost text (inline preview)
        BlinkCmpGhostText = { fg = colors.overlay0, italic = true },
        -- Copilot suggestion text
        CopilotSuggestion = { fg = colors.overlay0, italic = true },
      }
    end,
    integrations = {
      cmp = true,
      fidget = true,
      gitsigns = true,
      lsp_trouble = true,
      mason = true,
      mini = true,
      treesitter = true,
      treesitter_context = true,
      which_key = true,
      native_lsp = {
        enabled = true,
        virtual_text = {
          errors = { "italic" },
          hints = { "italic" },
          warnings = { "italic" },
          information = { "italic" },
        },
        underlines = {
          errors = { "undercurl" },
          hints = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
        },
        inlay_hints = {
          background = true,
        },
      },
    },
    styles = {
      comments = { "italic" },
      conditionals = { "italic" },
      functions = { "bold", "italic" },
    },
    compile_path = vim.fn.stdpath("cache") .. "/catppuccin",
  },
}
