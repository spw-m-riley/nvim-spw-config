local autocmds = require("onebeer.autocmds.helpers")
local create_group = autocmds.create_group
local create_autocmd = autocmds.create_autocmd
require("onebeer.settings.filetypes")
local lsp = vim.lsp

vim.lsp.config("*", {
  capabilities = {
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
  },
})

---Register LSP handler with custom configuration
---@param handler_name string
---@param handler_fn function
local function setup_lsp_handler(handler_name, handler_fn)
  lsp.handlers[handler_name] = handler_fn
end

setup_lsp_handler("textDocument/hover", function()
  return vim.lsp.buf.hover({ border = "rounded" })
end)

setup_lsp_handler("textDocument/signatureHelp", function()
  return vim.lsp.buf.signature_help({ border = "rounded" })
end)

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

if vim.fn.exepath("actions-languageserver") ~= "" then
  vim.lsp.enable("actionsls")
end

if vim.fn.exepath("gleam") ~= "" then
  vim.lsp.enable("gleam")
end

if vim.fn.exepath("gopls") ~= "" then
  vim.lsp.enable("gopls")
end

if vim.fn.exepath("vscode-html-language-server") ~= "" then
  vim.lsp.enable("html")
end

if vim.fn.exepath("terraform-ls") ~= "" then
  vim.lsp.enable("terraformls")
end

if vim.fn.exepath("typescript-language-server") ~= "" then
  vim.lsp.enable("ts_ls")
end
