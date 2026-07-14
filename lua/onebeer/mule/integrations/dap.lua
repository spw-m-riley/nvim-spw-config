---@class onebeer.mule.DapIntegration
local M = {}

---@return boolean, string|nil
function M.can_register()
  local ok = pcall(require, "dap")
  if not ok then
    return false, "nvim-dap is not available"
  end
  if vim.g.onebeer_mule_enable_experimental_dap ~= true then
    return false, "Mule DAP is disabled until a JDWP smoke test proves support"
  end
  if vim.fn.executable("java") ~= 1 then
    return false, "Java is required for Mule/MUnit JDWP debugging"
  end
  return true, nil
end

---@return boolean, string|nil
function M.setup()
  local ok, err = M.can_register()
  if not ok then
    return false, err
  end

  local dap = require("dap")
  dap.configurations.xml = dap.configurations.xml or {}
  dap.configurations.xml[#dap.configurations.xml + 1] = {
    hostName = "127.0.0.1",
    name = "Attach to Mule JVM (experimental)",
    port = 5005,
    request = "attach",
    type = "java",
  }
  return true, nil
end

return M
