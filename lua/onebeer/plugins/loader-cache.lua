local create_command = require("onebeer.autocmds.helpers").create_command

---Command to clear loader cache if needed
create_command("LoaderResetCache", function()
  if vim.loader then
    vim.loader.reset()
    vim.notify("Lua module cache cleared", vim.log.levels.INFO)
  end
end, { desc = "Reset Lua module cache" })

---@module "lazy"
---@type LazySpec
return {}
