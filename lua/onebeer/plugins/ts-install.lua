---@type onebeer.PluginSpec
return {
  "lewis6991/ts-install.nvim",
  event = "VeryLazy",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
  },
  ---@return nil
  config = function()
    vim.treesitter.language.register("terraform", "terraform-vars")

    require("ts-install").setup({
      auto_install = true,
      ensure_installed = {
        "astro",
        "bash",
        "css",
        "dockerfile",
        "gleam",
        "go",
        "gomod",
        "gowork",
        "graphql",
        "hcl",
        "html",
        "javascript",
        "jsdoc",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "python",
        "regex",
        "ruby",
        "rust",
        "scala",
        "scss",
        "sql",
        "svelte",
        "templ",
        "terraform",
        "toml",
        "tsx",
        "typescript",
        "yaml",
        "zig",
      },
    })
  end,
}
