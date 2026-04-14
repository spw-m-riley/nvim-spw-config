---@class ActionsRepoInfo
---@field id integer
---@field organizationOwned boolean

---@class ActionsRepoConfig
---@field id integer
---@field owner string
---@field name string
---@field organizationOwned boolean
---@field workspaceUri string

---@class ActionslsConfig
---@field cmd string[]
---@field filetypes string[]
---@field root_dir fun(bufnr: integer, on_dir: fun(path: string))
---@field handlers table<string, function>
---@field init_options ActionslsInitOptions
---@field on_new_config fun(new_config: ActionslsRuntimeConfig, root_dir: string)

---@class ActionslsInitOptions
---@field sessionToken string|nil
---@field repos ActionsRepoConfig[]|nil

---@class ActionslsRuntimeConfig
---@field init_options ActionslsInitOptions|nil

local actions_workflow_dirs = {
  "/.github/workflows",
  "/.forgejo/workflows",
  "/.gitea/workflows",
}
local lsp_settings = require("onebeer.settings.lsp")

local actions_server_cmd_candidates = {
  "actions-languageserver",
  "gh-actions-language-server",
  "actions-language-server",
}

---@param command string[]
---@return string|nil
local function run_system_command(command)
  local result = vim.system(command, { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end

  local stdout = vim.trim(result.stdout or "")
  return stdout ~= "" and stdout or nil
end

---@return string|nil
local function get_github_token()
  return run_system_command({ "gh", "auth", "token" })
end

---@param url string|nil
---@return string|nil owner
---@return string|nil repo
local function parse_github_remote(url)
  if not url or url == "" then
    return nil, nil
  end

  local owner, repo = url:match("git@github%.com:([^/]+)/([^/]+)")
  if owner and repo then
    return owner, repo:gsub("%.git$", "")
  end

  owner, repo = url:match("github%.com/([^/]+)/([^/]+)")
  if owner and repo then
    return owner, repo:gsub("%.git$", "")
  end

  return nil, nil
end

---@param owner string
---@param repo string
---@return ActionsRepoInfo|nil
local function get_repo_info(owner, repo)
  local result = run_system_command({
    "gh",
    "repo",
    "view",
    ("%s/%s"):format(owner, repo),
    "--json",
    "id,owner",
    "--template",
    "{{.id}}\t{{.owner.type}}",
  })
  if not result then
    return nil
  end

  local id, owner_type = result:match("^(%d+)\\t(.+)$")
  if id then
    return {
      id = tonumber(id),
      organizationOwned = owner_type == "Organization",
    }
  end

  return nil
end

---@param root_dir string|nil
---@return ActionsRepoConfig[]|nil
local function get_repos_config(root_dir)
  if not root_dir or root_dir == "" then
    return nil
  end

  local remote_url = run_system_command({ "git", "-C", root_dir, "remote", "get-url", "origin" })
  if not remote_url then
    return nil
  end

  local owner, name = parse_github_remote(remote_url)
  if not owner or not name then
    return nil
  end

  ---@type ActionsRepoInfo|nil
  local info = get_repo_info(owner, name)

  return {
    {
      id = info and info.id or 0,
      owner = owner,
      name = name,
      organizationOwned = info and info.organizationOwned or false,
      workspaceUri = vim.uri_from_fname(root_dir),
    },
  }
end

---@param path string|nil
---@return boolean
local function is_actions_workflow_dir(path)
  if not path or path == "" then
    return false
  end

  local normalized = path:gsub("\\", "/")
  for _, suffix in ipairs(actions_workflow_dirs) do
    if vim.endswith(normalized, suffix) then
      return true
    end
  end

  return false
end

---@return string
local function resolve_server_cmd()
  local cmd_path = lsp_settings.resolve_executable(actions_server_cmd_candidates)
  if cmd_path then
    return cmd_path
  end

  return actions_server_cmd_candidates[1]
end

---@param _ unknown
---@param result table
---@return string|nil
---@return nil
local function read_file_handler(_, result)
  if type(result) ~= "table" or type(result.path) ~= "string" then
    return nil, nil
  end

  local file_path = vim.uri_to_fname(result.path)
  if vim.fn.filereadable(file_path) ~= 1 then
    return nil, nil
  end

  local file = io.open(file_path, "r")
  if not file then
    return nil, nil
  end

  local text = file:read("*a")
  file:close()
  return text, nil
end

---@type string
local server_cmd = resolve_server_cmd()

---@type string|nil
local session_token = get_github_token()

---@type ActionslsConfig
return {
  cmd = { server_cmd, "--stdio" },
  filetypes = { "yaml", "yaml.ghactions" },
  root_dir = function(bufnr, on_dir)
    local filename = vim.api.nvim_buf_get_name(bufnr)
    if filename == "" then
      return
    end

    local parent = vim.fs.dirname(filename)
    if not is_actions_workflow_dir(parent) then
      return
    end

    local root = vim.fs.root(parent, { ".git" })
    if root then
      on_dir(root)
      return
    end

    on_dir(parent)
  end,
  handlers = {
    ["actions/readFile"] = read_file_handler,
  },
  ---@type ActionslsInitOptions
  init_options = {
    sessionToken = session_token,
  },
  ---@param new_config ActionslsRuntimeConfig
  ---@param root_dir string
  on_new_config = function(new_config, root_dir)
    new_config.init_options = new_config.init_options or {}
    new_config.init_options.sessionToken = session_token
    new_config.init_options.repos = get_repos_config(root_dir)
  end,
}
