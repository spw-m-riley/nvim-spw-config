---@type onebeer.PluginSpec
return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    signs = {
      add = { text = "│" },
      change = { text = "│" },
      delete = { text = "_" },
      topdelete = { text = "‾" },
      changedelete = { text = "~" },
      untracked = { text = "┆" },
    },
    signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
    numhl = false, -- Toggle with `:Gitsigns toggle_numhl`
    linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
    word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
    watch_gitdir = {
      follow_files = true,
    },
    attach_to_untracked = true,
    current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
    current_line_blame_opts = {
      virt_text = true,
      virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
      delay = 1000,
      ignore_whitespace = false,
      virt_text_priority = 100,
    },
    current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
    sign_priority = 6,
    update_debounce = 100,
    status_formatter = nil, -- Use default
    max_file_length = 40000, -- Disable if file is longer than this (in lines)
    preview_config = {
      -- Options passed to nvim_open_win
      border = "single",
      style = "minimal",
      relative = "cursor",
      row = 0,
      col = 1,
    },
    on_attach = function(bufnr)
      local gitsigns = require("gitsigns")

      local function map(mode, l, r, desc)
        local opts = { noremap = true, silent = true }
        opts.desc = desc
        opts.buffer = bufnr
        vim.keymap.set(mode, l, r, opts)
      end

      local function stage_range()
        gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end

      local function reset_range()
        gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end

      map("n", "<leader>cgb", function()
        gitsigns.blame_line({ full = true })
      end, "[C]ode [G]it [B]lame")
      map("n", "<leader>lhs", gitsigns.stage_hunk, "[L]ine [H]unk [S]tage")
      map("v", "<leader>lhs", stage_range, "[L]ine [H]unk [S]tage")
      map("n", "<leader>lhr", gitsigns.reset_hunk, "[L]ine [H]unk [R]eset")
      map("v", "<leader>lhr", reset_range, "[L]ine [H]unk [R]eset")
      map("n", "<leader>lhp", gitsigns.preview_hunk, "[L]ine [H]unk [P]review")
      map("n", "<leader>lhu", gitsigns.undo_stage_hunk, "[L]ine [H]unk [U]ndo stage")
      map("n", "<leader>lht", gitsigns.toggle_current_line_blame, "[L]ine [H]unk [T]oggle blame")

      -- Hunk navigation
      map("n", "]h", function()
        if vim.wo.diff then
          return "]c"
        end
        vim.schedule(function()
          gitsigns.next_hunk()
        end)
        return "<Ignore>"
      end, "Next hunk")

      map("n", "[h", function()
        if vim.wo.diff then
          return "[c"
        end
        vim.schedule(function()
          gitsigns.prev_hunk()
        end)
        return "<Ignore>"
      end, "Previous hunk")
    end,
  },
}
