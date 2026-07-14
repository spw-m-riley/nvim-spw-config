---@class onebeer.mule.Health
local M = {}

local catalog = require("onebeer.mule.catalog")
local config = require("onebeer.mule.config")
local detect = require("onebeer.mule.detect")

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

---@param path string
---@param catalog_path string
---@return boolean
local function active_lemminx_has_catalog(path, catalog_path)
  local project = detect.project(path)
  if project == nil then
    return false
  end

  local project_root = vim.fs.normalize(project.root)
  local normalized_catalog = vim.fs.normalize(catalog_path)
  for _, client in ipairs(vim.lsp.get_clients({ name = "lemminx" })) do
    local root = client.config and client.config.root_dir or nil
    local catalogs = client.settings and client.settings.xml and client.settings.xml.catalogs or {}
    if type(root) == "string" and vim.fs.normalize(root) == project_root then
      for _, configured_path in ipairs(catalogs) do
        if vim.fs.normalize(configured_path) == normalized_catalog then
          return true
        end
      end
    end
  end

  return false
end

local function check_current_mule_catalog()
  local path = vim.api.nvim_buf_get_name(0)
  if not detect.is_mule_xml(path) then
    return
  end

  local project = detect.project(path)
  if project == nil then
    return
  end

  local catalog_path = catalog.default_path(project)
  if vim.uv.fs_stat(catalog_path) == nil then
    vim.health.info("Mule XML catalog has not been generated for the current project.")
    return
  end

  vim.health.ok(("Mule XML catalog exists for the current project (`%s`)"):format(catalog_path))
  if active_lemminx_has_catalog(path, catalog_path) then
    vim.health.ok("Active project-local LemMinX client has the Mule XML catalog configured.")
    return
  end

  vim.health.info("No active project-local LemMinX client has the Mule XML catalog configured yet.")
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
  check_current_mule_catalog()
end

return M
