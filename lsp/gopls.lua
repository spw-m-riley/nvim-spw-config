---@class GoplsConfig
---@field settings table

---@type GoplsConfig
return {
  settings = {
    gopls = {
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = false,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
        ignoredError = true,
      },
      analyses = {
        unusedvariable = true,
        unusedparams = true,
        shadow = true,
      },
      staticcheck = true,
      usePlaceholders = true,
      semanticTokens = true,
      codelenses = {
        generate = true,
        gc_details = true,
        regenerate_cgo = true,
        run_govulncheck = true,
        test = false,
        tidy = true,
        upgrade_dependency = true,
        vendor = true,
      },
    },
  },
}
