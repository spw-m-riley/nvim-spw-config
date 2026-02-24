---@module "lazy"
---@type LazySpec
return {
  "vuki656/package-info.nvim",
  ft = { "json" },
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  opts = {
    autostart = true,
    hide_up_to_date = true,
  },
  keys = {
    { "<leader>ns", function() require("package-info").show() end, desc = "Show package info" },
    { "<leader>nt", function() require("package-info").toggle() end, desc = "Toggle package info" },
    { "<leader>nu", function() require("package-info").update() end, desc = "Update package" },
    { "<leader>nd", function() require("package-info").delete() end, desc = "Delete package" },
    { "<leader>ni", function() require("package-info").install() end, desc = "Install package" },
    { "<leader>np", function() require("package-info").change_version() end, desc = "Change package version" },
  },
}
