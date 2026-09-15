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
      ensure_install = {
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
        -- Svelte inherits the HTML query set, while ts-install only follows
        -- the parser metadata's html_tags dependency automatically.
        "html",
        "html_tags",
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

    -- Snacks quickfile can start highlighting before VeryLazy loads this
    -- plugin. Rebuild Svelte's query after ts-install adds its runtime path;
    -- otherwise the inherited HTML captures remain cached as missing.
    vim.schedule(function()
      pcall(function()
        vim.treesitter.query.get:clear()
      end)
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "svelte" then
          pcall(vim.treesitter.stop, buf)
          pcall(vim.treesitter.start, buf)
        end
      end
    end)
  end,
}
