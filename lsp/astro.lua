---@type vim.lsp.Config
-- Prefer a workspace-local TypeScript SDK; fall back to the one bundled with
-- the Mason astro-language-server package so the server can always start even
-- outside a TypeScript project.
local workspace_tsdk = vim.fn.finddir("node_modules/typescript/lib", vim.fn.getcwd() .. ";")
local mason_tsdk = vim.fn.stdpath("data") .. "/mason/packages/astro-language-server/node_modules/typescript/lib"

return {
  init_options = {
    typescript = {
      tsdk = (workspace_tsdk ~= "" and workspace_tsdk) or mason_tsdk,
    },
  },
  -- Conform owns Astro formatting; prevent astro-ls from competing.
  on_init = function(client)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
}
