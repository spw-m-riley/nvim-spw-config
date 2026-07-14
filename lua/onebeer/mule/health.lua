---@class onebeer.mule.Health
local M = {}

local config = require("onebeer.mule.config")

---@param name string
---@return boolean
local function executable(name)
  return vim.fn.executable(name) == 1
end

---@param tool string
---@param command string
---@param message string
local function required(tool, command, message)
  if executable(command) then
    vim.health.ok(("%s (`%s`) is available"):format(tool, command))
    return
  end

  vim.health.warn(("%s (`%s`) is not installed. %s"):format(tool, command, message))
end

---@param tool string
---@param command string
---@param message string
local function optional(tool, command, message)
  if executable(command) then
    vim.health.ok(("%s (`%s`) is available"):format(tool, command))
    return
  end

  vim.health.info(("%s (`%s`) is optional. %s"):format(tool, command, message))
end

---@param version string|nil
---@return integer|nil
local function node_major(version)
  if not version then
    return nil
  end
  return tonumber(version:match("v?(%d+)%."))
end

local function check_node_floor()
  if not executable("node") then
    vim.health.info("`node` is optional for Mule workflows unless `anypoint-cli-v4` is used")
    return
  end

  local output = vim.fn.system({ "node", "--version" })
  local major = node_major(output)
  if major and major >= 22 then
    vim.health.ok(("`node` satisfies anypoint-cli-v4 guidance (%s)"):format(vim.trim(output)))
    return
  end

  vim.health.warn(
    ("`node` is available but below the researched anypoint-cli-v4 floor of 22.x (%s)"):format(vim.trim(output))
  )
end

---@return nil
function M.check()
  vim.health.start("MuleSoft Tooling")
  vim.health.info("Mule checks do not read, request, or store MuleSoft credentials.")

  required("Java", "java", "Install a JDK compatible with the Mule runtime used by the project.")
  required(
    "Maven",
    config.command_name("maven") or "mvn",
    "Install Maven and configure any private MuleSoft repositories in Maven settings."
  )

  optional(
    "DataWeave CLI",
    config.command_name("dw") or "dw",
    "Install DataWeave CLI to enable `dw run`, `dw validate`, and `dw repl` wrappers."
  )
  optional("LemMinX", "lemminx", "Install LemMinX to enable XML/XSD validation for Mule XML catalog support.")
  optional(
    "Anypoint CLI v4",
    config.command_name("anypoint") or "anypoint-cli-v4",
    "Install and configure Anypoint CLI v4 to enable deploy/status/log wrappers."
  )
  optional("npm", "npm", "Install npm if Anypoint CLI v4 needs to be installed or updated.")
  check_node_floor()
end

return M
