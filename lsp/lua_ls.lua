---@type vim.lsp.Config
return {
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
        groupSeverity = {
          ["type-check"] = "Warning",
        },
        neededFileStatus = {
          ["codestyle-check"] = "None",
        },
      },
      type = {
        inferParamType = true,
        checkTableShape = true,
        weakNilCheck = false,
        weakUnionCheck = false,
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
}
