---@type onebeer.PluginSpec
return {
  "pmizio/typescript-tools.nvim",
  enabled = false,
  event = "BufReadPre",
  dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
  opts = {
    on_attach = function(client)
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
    end,
    settings = {
      separate_diagnostic_server = true,
      publish_diagnostic_on = "insert_leave",
      expose_as_code_action = "all",
      complete_function_calls = true,
      tsserver_file_preferences = {
        allowIncompleteCompletions = true,
        allowRenameOfImportPath = true,
        allowTextChangesInNewFiles = true,
        disableLineTextInReferences = true,
        displayPartsForJSDoc = true,
        generateReturnInDocTemplate = true,
        importModuleSpecifierEnding = "none",
        includeAutomaticOptionalChainCompletions = true,
        includeCompletionsForImportStatements = true,
        includeCompletionsWithClassMemberSnippets = true,
        includeCompletionsWithObjectLiteralMethodSnippets = true,
        includeCompletionsWithSnippetText = true,
        includeInlayParameterNameHints = "all",
        includeInlayParameterNameHintsWhenArgumentMatchesName = true,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayVariableTypeHintsWhenTypeMatchesName = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
        jsxAttributeCompletionStyle = "auto",
        providePrefixAndSuffixTextForRename = true,
        provideRefactorNotApplicableReason = true,
        quotePreference = "single",
        useLabelDetailsInCompletionEntries = true,
      },
    },
  },
}
