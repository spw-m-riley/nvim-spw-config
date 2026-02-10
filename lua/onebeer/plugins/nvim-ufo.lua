---@module "lazy"
---@type LazySpec
return {
  "kevinhwang91/nvim-ufo",
  event = "BufReadPost",
  dependencies = {
    "kevinhwang91/promise-async",
  },
  config = function()
    local ufo = require("ufo")
    ufo.setup({
      provider_selector = function(_, filetype, _)
        local exclude = {
          gitcommit = true,
          NeogitCommitMessage = true,
        }
        if exclude[filetype] then
          return { "indent" }
        end
        return { "lsp", "indent" }
      end,
      open_fold_hl_timeout = 0,
    })

    vim.keymap.set("n", "zR", ufo.openAllFolds, { desc = "Open all folds" })
    vim.keymap.set("n", "zM", ufo.closeAllFolds, { desc = "Close all folds" })
    vim.keymap.set("n", "zp", ufo.peekFoldedLinesUnderCursor, { desc = "Peek fold" })
  end,
}
