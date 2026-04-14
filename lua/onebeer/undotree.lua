local M = {}

local function notify_unavailable(message)
  vim.notify(message, vim.log.levels.ERROR, { title = "Undotree" })
end

local function load_native()
  local ok_packadd, packadd_err = pcall(vim.cmd.packadd, "nvim.undotree")
  if not ok_packadd then
    return nil, "Native undotree requires a Neovim build that ships the bundled nvim.undotree package.\n" .. packadd_err
  end

  local ok_require, undotree = pcall(require, "undotree")
  if not ok_require then
    return nil, "Failed to load native undotree.\n" .. undotree
  end

  return undotree
end

local function undotree_windows()
  local wins = {}

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "nvim-undotree" then
      table.insert(wins, win)
    end
  end

  return wins
end

local function close_open_windows()
  local wins = undotree_windows()

  for _, win in ipairs(wins) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  return #wins > 0
end

function M.toggle()
  local current_buf = vim.api.nvim_get_current_buf()
  local current_is_undotree = vim.bo[current_buf].filetype == "nvim-undotree"

  if close_open_windows() and current_is_undotree then
    return
  end

  local undotree, err = load_native()
  if not undotree then
    notify_unavailable(err)
    return
  end

  undotree.open({ command = "leftabove 30vnew" })
end

function M.setup()
  local undotree = load_native()
  if undotree and vim.fn.exists(":Undotree") == 2 then
    pcall(vim.api.nvim_del_user_command, "Undotree")
  end

  vim.api.nvim_create_user_command("Undotree", function()
    M.toggle()
  end, { desc = "Toggle the native undo tree" })
end

return M
