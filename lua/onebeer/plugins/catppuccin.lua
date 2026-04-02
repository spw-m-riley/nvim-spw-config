---@type table
local opts = {
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
}

---@return nil
local function apply()
  if vim.g.onebeer_catppuccin_applied then
    return
  end

  pcall(vim.cmd.packadd, "catppuccin")
  require("catppuccin").setup(opts)

  local ok, err = pcall(vim.cmd.colorscheme, "catppuccin")
  if ok then
    vim.g.onebeer_catppuccin_applied = true
    return
  end

  vim.notify(("Failed to load catppuccin: %s"):format(err), vim.log.levels.WARN, { title = "Colorscheme" })
end

---@type onebeer.PluginSpec
return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 1000,
  opts = opts,
  init = function()
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = apply,
    })
  end,
  config = function()
    apply()
  end,
}
