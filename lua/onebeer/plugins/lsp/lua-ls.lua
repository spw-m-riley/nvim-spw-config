---@module "lazy"
---@type LazySpec
return {
  "neovim/nvim-lspconfig",
  ft = "lua",
  config = function()
    -- More aggressive lua_ls workspace restrictions
    vim.lsp.enable("lua_ls", {
      settings = {
        Lua = {
          runtime = {
            version = "LuaJIT",
          },
          diagnostics = {
            -- Reduce diagnostic frequency
            workspaceDelay = 3000, -- 3 second delay before workspace diagnostics
            workspaceRate = 20, -- Check 20% of files at a time
            globals = { "vim" },
            neededFileStatus = {
              ["codestyle-check"] = "None",
            },
          },
          workspace = {
            checkThirdParty = false, -- Don't prompt about third party configs
            -- Limit scanning to config directory only
            library = {
              vim.fn.stdpath("config"),
              "${3rd}/luv/library",
            },
            -- Ignore large directories
            ignoreDir = {
              ".git",
              "node_modules",
              ".vscode",
              ".idea",
              "dist",
              "build",
              "target",
              ".cache",
              ".local",
            },
            -- Only scan lua files in nvim config
            ignoreSubmodules = true,
            maxPreload = 2000,
            preloadFileSize = 50000,
          },
          telemetry = {
            enable = false,
          },
          hint = {
            enable = true, -- Keep inlay hints
            setType = true,
          },
          format = {
            enable = false, -- Disable lua_ls formatting (use stylua via conform)
          },
        },
      },
    })
  end,
}
