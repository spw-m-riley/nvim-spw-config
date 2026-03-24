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
