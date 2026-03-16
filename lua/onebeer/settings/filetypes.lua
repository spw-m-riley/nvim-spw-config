---Shared filetype definitions and mappings
---@class FiletypeConfig
local M = {
  astro = "astro",
  css = "css",
  dockerfile = "dockerfile",
  dotenv = "dotenv",
  eruby = "eruby",
  gitcommit = "gitcommit",
  ghactions = "yaml.ghactions",
  gleam = "gleam",
  go = "go",
  hcl = "hcl",
  html = "html",
  http = "http",
  javascript = "javascript",
  javascriptreact = "javascriptreact",
  json = "json",
  lua = "lua",
  markdown = "markdown",
  log = "log",
  protobuf = "protobuf",
  python = "python",
  ruby = "ruby",
  rust = "rust",
  sh = "sh",
  sql = "sql",
  svelte = "svelte",
  templ = "templ",
  terraform = "terraform",
  typescript = "typescript",
  typescriptreact = "typescriptreact",
  yaml = "yaml",
  zig = "zig",
  zir = "zir",
  zsh = "zsh",
}

vim.filetype.add({
  extension = {
    astro = M.astro,
    templ = M.templ,
    http = M.http,
    env = M.dotenv,
    envrc = "sh",
    log = "log",
  },
  filename = {
    [".env"] = M.dotenv,
    [".env.local"] = M.dotenv,
    [".envrc"] = "sh",
    ["Taskfile"] = M.yaml,
    ["Taskfile.yml"] = M.yaml,
    ["Taskfile.yaml"] = M.yaml,
  },
  pattern = {
    [".*/%.github/workflows/.*%.ya?ml"] = M.ghactions,
    ["Taskfile%..+%.ya?ml"] = M.yaml,
    ["taskfiles/.+%.[Yy][Aa]?[Mm][Ll]"] = M.yaml,
  },
})

return M
