---@class OneBeerStarterFooters
local M = {}
local total_plugins = require("lazy").stats().loaded

---Summary footer referencing the number of loaded plugins.
M.Plugins = "Loaded " .. total_plugins .. " plugins  "

return M
