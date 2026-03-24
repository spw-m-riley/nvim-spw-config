local ui = require("onebeer.ui")

---@module "lazy"
---@type LazySpec
return {
  "cshuaimin/ssr.nvim",
  opts = function()
    return {
      border = ui.float_winopts().border,
    }
  end,
  config = function(_, opts)
    require("onebeer.patches.ssr").apply()
    require("ssr").setup(opts)
  end,
  keys = {
    {
      "<leader>cs",
      function()
        require("ssr").open()
      end,
      mode = { "n", "x" },
      desc = "[C]ode [S]tructural replace",
    },
  },
}
