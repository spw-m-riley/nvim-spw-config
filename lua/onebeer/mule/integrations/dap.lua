---@class onebeer.mule.DapIntegration
local M = {}

local detect = require("onebeer.mule.detect")

---@param path string
---@return boolean
function M.is_munit_file(path)
  if type(path) ~= "string" or path == "" or path:match("%.xml$") == nil then
    return false
  end

  local project = detect.project(path)
  if project == nil then
    return false
  end

  local relative = vim.fs.relpath(project.munit_dir, path)
  return relative ~= nil and not vim.startswith(relative, "..")
end

---@return boolean, string|nil
function M.can_debug()
  if vim.g.onebeer_mule_enable_experimental_dap ~= true then
    return false, "Mule DAP is disabled until a JDWP smoke test proves support"
  end
  if vim.fn.executable("java") ~= 1 then
    return false, "Java is required for Mule/MUnit JDWP debugging"
  end

  local ok, dap = pcall(require, "dap")
  if not ok then
    return false, "nvim-dap is not available"
  end
  if type(dap.adapters) ~= "table" or dap.adapters.java == nil then
    return false, "A registered nvim-dap Java adapter is required for Mule/MUnit JDWP debugging"
  end

  return true, nil
end

---@param path string
---@return boolean, string|nil
function M.guard(path)
  if not M.is_munit_file(path) then
    return true, nil
  end
  return M.can_debug()
end

---@return boolean, string|nil
function M.setup()
  local ok, err = M.can_debug()
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
