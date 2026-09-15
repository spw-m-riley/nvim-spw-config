---@type onebeer.PluginSpec
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  ---@return nil
  config = function()
    local treesitter = require("nvim-treesitter")
    local supported = {}
    for _, lang in ipairs(treesitter.get_available()) do
      supported[lang] = true
    end
    local installing = {}
    local pending = {}
    local requested = {}
    local seen = {}

    -- Terraform variable files use Terraform's parser, but have their own
    -- filetype in Vim's filetype detection.
    vim.treesitter.language.register("terraform", "terraform-vars")

    local function parser_installed(lang)
      return pcall(vim.treesitter.language.inspect, lang)
    end

    local function configure_buffer(buf, lang)
      if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype == "" then
        return false
      end

      local ok = pcall(vim.treesitter.start, buf, lang)
      if not ok then
        return false
      end

      if #vim.api.nvim_get_runtime_file(("queries/%s/indents.scm"):format(lang), true) > 0 then
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
      for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        vim.wo[win].foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.wo[win].foldmethod = "expr"
      end
      return true
    end

    local function start_pending(lang)
      local buffers = pending[lang] or {}
      pending[lang] = nil
      for buf in pairs(buffers) do
        if vim.api.nvim_buf_is_valid(buf) then
          local filetype = vim.bo[buf].filetype
          if vim.treesitter.language.get_lang(filetype) == lang then
            configure_buffer(buf, lang)
          end
        end
      end
    end

    local function install_parser(lang, buf)
      pending[lang] = pending[lang] or {}
      pending[lang][buf] = true
      if installing[lang] then
        return
      end

      installing[lang] = true
      local ok, task = pcall(treesitter.install, lang)
      if not ok or type(task) ~= "table" or type(task.await) ~= "function" then
        installing[lang] = nil
        pending[lang] = nil
        return
      end

      local awaited = pcall(task.await, task, function(err, success)
        installing[lang] = nil
        if err or success == false then
          for buf in pairs(pending[lang] or {}) do
            if requested[buf] then
              requested[buf][lang] = nil
            end
          end
        end
        vim.schedule(function()
          start_pending(lang)
        end)
      end)
      if not awaited then
        installing[lang] = nil
        for buf in pairs(pending[lang] or {}) do
          if requested[buf] then
            requested[buf][lang] = nil
          end
        end
        pending[lang] = nil
      end
    end

    local function on_filetype(ev)
      local buf = ev.buf
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end

      seen[buf] = true
      local filetype = vim.bo[buf].filetype
      local lang = vim.treesitter.language.get_lang(filetype)
      if not lang or not supported[lang] then
        return
      end

      if parser_installed(lang) then
        if requested[buf] then
          requested[buf][lang] = nil
        end
        configure_buffer(buf, lang)
      elseif not (requested[buf] and requested[buf][lang]) then
        requested[buf] = requested[buf] or {}
        requested[buf][lang] = true
        install_parser(lang, buf)
      end
    end

    local group = vim.api.nvim_create_augroup("OneBeerTreesitter", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      callback = on_filetype,
    })

    -- FileType may have fired before the plugin was loaded (notably for files
    -- passed on Neovim's command line).
    vim.schedule(function()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if not seen[buf] and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype ~= "" then
          on_filetype({ buf = buf })
        end
      end
    end)
  end,
}
