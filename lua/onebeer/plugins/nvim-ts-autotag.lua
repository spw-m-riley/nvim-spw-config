---@module "lazy"
---@type LazySpec
return {
  "windwp/nvim-ts-autotag",
  event = "InsertEnter",
  opts = {
    opts = {
      enable_close = true,          -- Auto close tags
      enable_rename = true,          -- Auto rename pairs of tags
      enable_close_on_slash = false, -- Auto close on trailing </
    },
    -- Per-filetype settings can be added here if needed
    -- per_filetype = {
    --   ["html"] = {
    --     enable_close = false
    --   }
    -- }
  },
}
