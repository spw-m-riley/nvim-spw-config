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
---@field root_markers string[]
---@field workspace_required boolean
---@field init_options ActionslsInitOptions
---@field on_new_config fun(new_config: ActionslsRuntimeConfig, root_dir: string)

---@class ActionslsInitOptions
---@field sessionToken string|nil
---@field repos ActionsRepoConfig[]|nil

---@class ActionslsRuntimeConfig
---@field init_options ActionslsInitOptions|nil

---@return string|nil
local function get_github_token()
  local handle = io.popen("gh auth token 2>/dev/null")
  if not handle then
    return nil
  end

  local token = handle:read("*a"):gsub("%s+", "")
  handle:close()
  return token ~= "" and token or nil
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
  local cmd = string.format(
    "gh repo view %s/%s --json id,owner --template '{{.id}}\\t{{.owner.type}}' 2>/dev/null",
    owner,
    repo
  )
  local handle = io.popen(cmd)
  if not handle then
    return nil
  end

  local result = handle:read("*a"):gsub("%s+$", "")
  handle:close()

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

  local handle = io.popen(string.format("git -C %q remote get-url origin 2>/dev/null", root_dir))
  if not handle then
    return nil
  end

  local remote_url = handle:read("*a"):gsub("%s+", "")
  handle:close()
  if remote_url == "" then
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

---@type string
local server_cmd = vim.fn.exepath("actions-languageserver")
if server_cmd == "" then
  server_cmd = "actions-languageserver"
end

---@type string|nil
local session_token = get_github_token()

---@type ActionslsConfig
return {
  cmd = { server_cmd, "--stdio" },
  filetypes = { "yaml.ghactions" },
  root_markers = { ".git" },
  workspace_required = false,
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
