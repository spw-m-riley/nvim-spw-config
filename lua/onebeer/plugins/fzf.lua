local ui = require("onebeer.ui")

---@module "lazy"
---@type LazySpec
return {
  "ibhagwan/fzf-lua",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    "elanmed/fzf-lua-frecency.nvim",
  },
  cmd = { "FzfLua" },
  opts = {
    { "skim" },
    file_icons = true,
    winopts = ui.float_winopts({
      treesitter = false,
      preview = { default = "bat" },
    }),
    files = {
      git_icons = true,
      fzf_opts = { ["--ansi"] = false },
    },
    silent = true,
    grep = {
      rg_opts = table.concat({
        "--hidden",
        "--glob",
        "!.git/",
        "--column",
        "--line-number",
        "--no-heading",
        "--color=never",
        "--smart-case",
        "--follow",
        "--trim",
      }, " "),
    },
  },
  config = function(_, opts)
    local fzf = require("fzf-lua")
    opts.grep = opts.grep or {}
    opts.grep.actions = vim.tbl_extend(
      "force",
      opts.grep.actions or {},
      { ["ctrl-q"] = { fn = fzf.actions.file_sel_to_qf, prefix = "select-all" } }
    )
    fzf.setup(opts)
    require("fzf-lua-frecency").setup()
    fzf.register_ui_select()
  end,
  keys = {
    { "<leader>sb", "<CMD>FzfLua buffers<CR>", desc = "[S]earch open [B]uffers" },
    { "<leader>sf", "<CMD>FzfLua frecency cwd_only=true<CR>", desc = "[S]earch [F]iles" },
    { "<leader>sg", "<CMD>FzfLua live_grep<CR>", desc = "[S]earch with [G]rep" },
    { "<leader>sh", "<CMD>FzfLua helptags<CR>", desc = "[S]earch [H]elp" },
    { "<leader>sk", "<CMD>FzfLua keymaps<CR>", desc = "[S]earch [K]eymaps" },
    { "<leader>sc", "<CMD>FzfLua commands<CR>", desc = "[S]earch [C]ommands" },
    {
      "<leader>sr",
      function()
        require("fzf-lua").oldfiles({
          cwd = vim.fn.getcwd(),
        })
      end,
      desc = "[S]earch [R]ecent files",
    },
    { "<leader>sR", "<CMD>FzfLua resume<CR>", desc = "[S]earch [R]esume picker" },
    { "<leader>ss", "<CMD>FzfLua lsp_document_symbols<CR>", desc = "[S]earch [S]ymbols" },
    { "<leader>st", "<CMD>FzfLua lsp_workspace_symbols<CR>", desc = "[S]earch [T]ags" },
    { "<leader>sdd", "<CMD>FzfLua diagnostics_document<CR>", desc = "[D]ocument" },
    { "<leader>sdw", "<CMD>FzfLua diagnostics_workspace<CR>", desc = "[W]orkspace" },
    { "<leader>svb", "<CMD>FzfLua git_blame<CR>", desc = "[B]lame" },
    { "<leader>svc", "<CMD>FzfLua git_commits<CR>", desc = "[C]ommits" },
    { "<leader>svB", "<CMD>FzfLua git_branches<CR>", desc = "[B]ranches" },
    { "<leader>svs", "<CMD>FzfLua git_status<CR>", desc = "[S]tatus" },
    { "<leader>sq", "<CMD>FzfLua quickfix<CR>", desc = "[S]earch [Q]uickfix" },
    { "<leader>sl", "<CMD>FzfLua loclist<CR>", desc = "[S]earch Location [L]ist" },
  },
}
