local icons = require("onebeer.settings.icons")

vim.diagnostic.config({
  underline = true,
  update_in_insert = false,
  virtual_text = {
    prefix = "",
    spacing = 2,
    source = "if_many",
  },
  severity_sort = true,
  signs = icons.get_diagnostic_signs(),
})
