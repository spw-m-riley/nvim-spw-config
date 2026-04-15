local autocmds = require("onebeer.autocmds.helpers")
local create_group = autocmds.create_group
local create_autocmd = autocmds.create_autocmd
local opt = vim.opt

local data_dir = vim.fn.stdpath("data")

---@class OneBeerSettings
local M = {}

---Apply default editor options, keymaps, and supporting autocommands.
---@return nil
function M.defaults()
  vim.fn.mkdir(data_dir .. "/backups", "p")
  vim.fn.mkdir(data_dir .. "/undo", "p")
  local has_keymaps, keymaps = pcall(require, "onebeer.keymaps")

  if has_keymaps then
    keymaps.defaults()
  end

  -- Core editor settings
  opt.autoindent = true
  opt.background = "dark"
  opt.backspace = "indent,eol,start"
  opt.backup = true
  opt.backupcopy = "auto"
  opt.backupdir = data_dir .. "/backups"
  opt.breakindent = true
  opt.clipboard = "unnamedplus"
  opt.cmdheight = 0
  opt.cursorline = true
  opt.encoding = "UTF-8"
  opt.expandtab = true
  opt.fillchars = {
    eob = " ",
    fold = " ",
    foldopen = "",
    foldclose = "",
    foldsep = " ",
  }
  opt.foldcolumn = "1"
  opt.foldenable = true
  opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
  opt.foldlevel = 99
  opt.foldlevelstart = 99
  opt.foldmethod = "expr"
  opt.guifont = "MonoLisa Nerd Font"
  opt.history = 1000
  opt.laststatus = 3
  opt.magic = true
  opt.mouse = "a"
  opt.number = true
  opt.relativenumber = true
  opt.scrolloff = 8
  opt.smoothscroll = true
  opt.winborder = "rounded"
  opt.pumborder = "rounded"
  opt.sessionoptions = "buffers,curdir,tabpages,winsize,help,globals,skiprtp,folds"
  opt.shiftwidth = 2
  opt.showmatch = true
  opt.signcolumn = "yes"
  opt.smartindent = true
  opt.softtabstop = 2
  opt.splitbelow = true
  opt.splitright = true
  opt.splitkeep = "screen"
  opt.statusline = "%!v:lua.require'onebeer.ui.statusline'.render()"
  opt.tabstop = 2
  opt.termguicolors = true
  opt.title = true
  opt.undodir = data_dir .. "/undo"
  opt.undofile = true
  opt.updatetime = 250
  opt.viewoptions = "folds,cursor"
  opt.visualbell = true
  opt.wildmenu = true
  opt.winbar = "%{%v:lua.require'onebeer.ui'.winbar()%}"
  opt.writebackup = true

  opt.shortmess:append({
    f = true,
    l = true,
    m = true,
    n = true,
    r = true,
    s = true,
    W = true,
    I = true,
    q = true,
    S = true,
    C = true,
  })

  vim.opt_global.shortmess:remove("F") -- NOTE: Without doing this, autocommands that deal with filetypes prohibit messages from being shown

  local highlight_group = create_group("OneBeerHighlights")
  local function set_inlay_hint_hl()
    vim.api.nvim_set_hl(0, "LspInlayHint", { link = "Comment" })
  end
  local function set_winbar_hl()
    vim.api.nvim_set_hl(0, "OneBeerWinbarPath", { link = "WinBar" })
    vim.api.nvim_set_hl(0, "OneBeerWinbarIcon", { link = "Title" })
    vim.api.nvim_set_hl(0, "OneBeerWinbarModified", { link = "DiagnosticWarn" })
    vim.api.nvim_set_hl(0, "OneBeerWinbarReadonly", { link = "DiagnosticError" })
  end
  local function set_pack_winbar_hl()
    vim.api.nvim_set_hl(0, "OneBeerPackWinbarTitle", { link = "Title" })
    vim.api.nvim_set_hl(0, "OneBeerPackWinbarIcon", { link = "Special" })
    vim.api.nvim_set_hl(0, "OneBeerPackWinbarMuted", { link = "Comment" })
    vim.api.nvim_set_hl(0, "OneBeerPackWinbarHint", { link = "Comment" })
    vim.api.nvim_set_hl(0, "OneBeerPackWinbarUpdate", { link = "DiagnosticWarn" })
    vim.api.nvim_set_hl(0, "OneBeerPackWinbarError", { link = "DiagnosticError" })
    vim.api.nvim_set_hl(0, "OneBeerPackWinbarSame", { link = "DiagnosticHint" })
  end
  local function set_pack_review_hl()
    vim.api.nvim_set_hl(0, "OneBeerPackReviewPhaseLoading", { link = "DiagnosticHint" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewPhaseReady", { link = "DiagnosticOk" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewPhaseApplying", { link = "DiagnosticWarn" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewPhaseDone", { link = "DiagnosticOk" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewPhaseError", { link = "DiagnosticError" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewHeaderTitle", { link = "Title" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewHeaderCurrent", { link = "Normal" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewProgressBarFill", { link = "DiagnosticInfo" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewProgressBarTrack", { link = "Comment" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewProgressPercent", { link = "Number" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewProgressSpinner", { link = "DiagnosticInfo" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewRowToggle", { link = "Comment" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewRowNameQueued", { link = "Comment" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewRowNameChecking", { link = "DiagnosticInfo" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewRowNameApplying", { link = "DiagnosticWarn" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewRowNameUpdate", { link = "Function" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewRowNameSame", { link = "Comment" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewRowNameDone", { link = "DiagnosticOk" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewRowNameError", { link = "DiagnosticError" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewStatusQueued", { link = "Comment" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewStatusChecking", { link = "DiagnosticInfo" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewStatusApplying", { link = "DiagnosticWarn" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewStatusUpdate", { link = "DiagnosticWarn" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewStatusSame", { link = "Comment" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewStatusDone", { link = "DiagnosticOk" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewStatusError", { link = "DiagnosticError" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewSummaryQueued", { link = "Comment" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewSummaryChecking", { link = "Comment" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewSummaryApplying", { link = "Comment" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewSummaryUpdate", { link = "Comment" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewSummarySame", { link = "NonText" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewSummaryDone", { link = "DiagnosticOk" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewSummaryError", { link = "DiagnosticError" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewDetailLabel", { link = "Label" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewDetailValue", { link = "Normal" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewDetailMuted", { link = "NonText" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewActionKey", { link = "Special" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewActionText", { link = "Comment" })
    vim.api.nvim_set_hl(0, "OneBeerPackReviewMessage", { link = "Normal" })
  end
  set_inlay_hint_hl()
  set_winbar_hl()
  set_pack_winbar_hl()
  set_pack_review_hl()
  create_autocmd("ColorScheme", {
    group = highlight_group,
    callback = function()
      set_inlay_hint_hl()
      set_winbar_hl()
      set_pack_winbar_hl()
      set_pack_review_hl()
    end,
  })

  --  Return to the same position in the file when reopening
  local restore_cursor_group = create_group("OneBeerRestoreCursor")
  create_autocmd("BufReadPost", {
    group = restore_cursor_group,
    pattern = "*",
    callback = function()
      local mark = vim.api.nvim_buf_get_mark(0, '"')
      local lcount = vim.api.nvim_buf_line_count(0)
      if mark[1] > 0 and mark[1] <= lcount then
        pcall(vim.api.nvim_win_set_cursor, 0, mark)
      end
    end,
  })
end

---Extend defaults with Neovide-specific global options.
---@return nil
function M.neovide()
  M.defaults()

  local neovide_config = {
    neovide_transparency = 0.8,
    neovide_cursor_trail_length = 0.1,
    neovide_remember_window_size = true,
  }

  for name, value in pairs(neovide_config) do
    vim.g[name] = value
  end
end

return M
