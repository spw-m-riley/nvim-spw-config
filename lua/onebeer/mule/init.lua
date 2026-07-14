---@class OneBeerMule
local M = {}

---@param opts? onebeer.mule.Config
---@return nil
function M.setup(opts)
  require("onebeer.mule.config").setup(opts)
end

return M
