---@class OneBeerKeymaps
local M = {}

---Apply baseline keymaps for the OneBeer profile.
---@return nil
function M.defaults()
  vim.g.mapleader = " "
  -- vim.g.maplocalleader = " "

  local map = require("onebeer.utils").map
  require("onebeer.undotree").setup()
  -- Turn off hlsearch
  map("n", "<leader>,", ":nohl<cr>", { desc = "HLS off" })
  map("n", "<leader>uh", "<cmd>OneBeerHelp<cr>", { desc = "[U]I [H]elp overview" })
  map("n", "<leader>ud", "<cmd>OneBeerDoctor<cr>", { desc = "[U]I [D]iagnostics doctor" })
  map("n", "<leader>ul", "<cmd>InspectLog<cr>", { desc = "[U]I [L]og file" })
  map("n", "<leader>uf", "<cmd>FormatToggleBuffer<cr>", { desc = "[U]I toggle [F]ormat (buffer)" })
  map("n", "<leader>uF", "<cmd>FormatToggle<cr>", { desc = "[U]I toggle [F]ormat (global)" })
  map("n", "<leader>uB", "<cmd>LintToggleBuffer<cr>", { desc = "[U]I toggle lint [B]uffer" })
  map("n", "<leader>uL", "<cmd>LintToggle<cr>", { desc = "[U]I toggle [L]int (global)" })
  map("n", "<leader>uu", function()
    require("onebeer.undotree").toggle()
  end, { desc = "[U]ndo [U]ndo tree" })

  map("n", "<C-w>H", "<C-w>3<", { desc = "Resize window - left" })
  map("n", "<C-w>L", "<C-w>3>", { desc = "Resize window - right" })
  map("n", "<C-w>J", "<C-w>2-", { desc = "Resize window - down" })
  map("n", "<C-w>K", "<C-w>2+", { desc = "Resize window - up" })

  map("n", "<leader>mj", ":m .+1<CR>==", { desc = "[M]ove line down" })
  map("n", "<leader>mk", ":m .-2<CR>==", { desc = "[M]ove line up" })
  map("i", "<leader>mj", "<ESC>:m .+1<CR>==", { desc = "[M]ove line down" })
  map("i", "<leader>mk", "<ESC>:m .-2<CR>==", { desc = "[M]ove line up" })
  map("v", "<leader>mj", ":m '>+1<CR>gv=gv", { desc = "[M]ove line down" })
  map("v", "<leader>mk", ":m '<-2<CR>gv=gv", { desc = "[M]ove line up" })

  map({ "n", "v" }, "<leader>jg", function()
    require("onebeer.tools.jsontogo").generate()
  end, { desc = "JSON to Go structs via jq + gojson" })

  map({ "n", "v" }, "<leader>jt", function()
    require("onebeer.tools.jsontots").generate()
  end, { desc = "JSON to Typescript via jq + quicktype" })

  map("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })
  map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
  map("n", "<leader>cd", function()
    local cfg = vim.diagnostic.config()
    local enabled = cfg.virtual_lines ~= false
    vim.diagnostic.config({
      virtual_lines = enabled and false or { current_line = true },
      virtual_text = enabled and { prefix = "", spacing = 2, source = "if_many" } or false,
    })
  end, { desc = "[C]ode [D]iagnostics toggle" })
  map("n", "zp", function()
    local line = vim.fn.line(".")
    local fold_start = vim.fn.foldclosed(line)
    if fold_start == -1 then
      return
    end
    local fold_end = vim.fn.foldclosedend(line)
    local lines = vim.api.nvim_buf_get_lines(0, fold_start - 1, fold_end, false)
    vim.lsp.util.open_floating_preview(lines, vim.bo.filetype, {})
  end, { desc = "Peek fold" })

  -- View messages
  map("n", "<leader>um", ":messages<CR>", { desc = "[U]I [M]essages" })
end

return M
