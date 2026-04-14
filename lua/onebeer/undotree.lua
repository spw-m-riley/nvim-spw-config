local M = {}

local function notify_unavailable(message)
  vim.notify(message, vim.log.levels.ERROR, { title = "Undotree" })
end

function M.toggle()
  local ok_packadd, packadd_err = pcall(vim.cmd.packadd, "nvim.undotree")
  if not ok_packadd then
    notify_unavailable(
      "Native undotree requires a Neovim build that ships the bundled nvim.undotree package.\n" .. packadd_err
    )
    return
  end

  local ok_require, undotree = pcall(require, "undotree")
  if not ok_require then
    notify_unavailable("Failed to load native undotree.\n" .. undotree)
    return
  end

  undotree.open({ command = "leftabove 30vnew" })
end

return M
