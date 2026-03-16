local autocmds = require("onebeer.autocmds.helpers")
local create_group = autocmds.create_group
local create_autocmd = autocmds.create_autocmd
require("onebeer.settings.filetypes")
local lsp = vim.lsp
local M = {}

local base_capabilities = {
  textDocument = {
    completion = {
      completionItem = {
        snippetSupport = true,
      },
    },
    semanticTokens = {
      multilineTokenSupport = true,
    },
  },
}

M.base_capabilities = vim.deepcopy(base_capabilities)

vim.lsp.config("*", {
  capabilities = vim.deepcopy(base_capabilities),
})

---@param client vim.lsp.Client
local function disable_formatting(client)
  if not client or not client.server_capabilities then
    return
  end

  client.server_capabilities.documentFormattingProvider = false
  client.server_capabilities.documentRangeFormattingProvider = false
end

M.disable_formatting = disable_formatting

local original_progress = lsp.handlers["$/progress"]
lsp.handlers["$/progress"] = function(err, result, ctx, config)
  if original_progress then
    original_progress(err, result, ctx, config)
  end
  if err or not result or not ctx then
    return
  end
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not client then
    return
  end
  local value = result.value
  if not value or type(value) ~= "table" then
    return
  end
  local kind = value.kind or "report"

  -- LSP can emit very frequent progress updates; only notify once when it finishes.
  if kind ~= "end" then
    return
  end

  local message = value.message or value.title or kind
  vim.notify(message, vim.log.levels.INFO, {
    title = ("LSP • %s"):format(client.name),
    icon = "",
    id = ("lsp-progress-%s"):format(result.token or client.name),
  })
end

---Wrap LSP floating preview to always use rounded borders
vim.lsp.util.open_floating_preview = (function(orig)
  return function(contents, syntax, opts, ...)
    opts = opts or {}
    opts.border = opts.border or "rounded"
    return orig(contents, syntax, opts, ...)
  end
end)(vim.lsp.util.open_floating_preview)

local semantic_tokens = vim.lsp.semantic_tokens
if semantic_tokens and semantic_tokens.enable then
  local semantic_group = create_group("OneBeerSemanticTokens")

  create_autocmd("LspAttach", {
    group = semantic_group,
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client and client.server_capabilities.semanticTokensProvider then
        semantic_tokens.enable(true, { bufnr = ev.buf })
      end
    end,
  })

  create_autocmd("LspDetach", {
    group = semantic_group,
    callback = function(ev)
      semantic_tokens.enable(false, { bufnr = ev.buf })
    end,
  })
end

---@param command string
---@return string
local function mason_bin_path(command)
  return ("%s/mason/bin/%s"):format(vim.fn.stdpath("data"), command)
end

M.mason_bin_path = mason_bin_path

---@param commands string|string[]
---@return string|nil
local function resolve_executable(commands)
  if type(commands) == "string" then
    commands = { commands }
  end

  for _, command in ipairs(commands) do
    local command_path = vim.fn.exepath(command)
    if command_path ~= "" then
      return command_path
    end

    local mason_command = mason_bin_path(command)
    if vim.fn.executable(mason_command) == 1 then
      return mason_command
    end
  end

  return nil
end

M.resolve_executable = resolve_executable

---@param command string
---@return boolean
local function is_executable(command)
  return resolve_executable(command) ~= nil
end

M.is_executable = is_executable

---@param commands string[]
---@return boolean
local function has_any_executable(commands)
  for _, command in ipairs(commands) do
    if is_executable(command) then
      return true
    end
  end
  return false
end

M.has_any_executable = has_any_executable

return M
