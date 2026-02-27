local autocmds = require("onebeer.autocmds.helpers")
local create_group = autocmds.create_group
local create_autocmd = autocmds.create_autocmd
local create_command = autocmds.create_command
local state = require("onebeer.state")
local utils = require("onebeer.utils")

---Helper to check LSP capability and set keymap
---@param capability string
---@param mode string
---@param key string
---@param rhs string|function
---@param opts table
---@param client_id integer
---@return boolean
local function on_lsp_capability(capability, mode, key, rhs, opts, client_id)
  local client = vim.lsp.get_client_by_id(client_id)
  if client ~= nil and client.server_capabilities[capability] then
    utils.map(mode, key, rhs, opts)
    return true
  end
  return false
end

---Reload a Blink completion provider when its client connects.
---@param provider string
local function reload_blink_provider(provider)
  local ok, blink = pcall(require, "blink.cmp")
  if not ok or type(blink.reload) ~= "function" then
    return
  end
  blink.reload(provider)
end

-- Groups
local lintGrp = create_group("OneBeerWorkflowLint")
local lspGrp = create_group("OneBeerLsp")
local ynkGrp = create_group("OneBeerHighlightYank")
local filetypeGrp = create_group("OneBeerFiletype")

create_autocmd("FileType", {
  pattern = { "terraform-vars" },
  group = filetypeGrp,
  callback = function()
    vim.treesitter.start()
    vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
    vim.wo[0][0].foldmethod = "expr"
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})

-- Commands
-- UI
create_autocmd("TextYankPost", {
  group = ynkGrp,
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- Formatting and linting commands
create_autocmd("BufWritePost", {
  pattern = ".github/workflows/*",
  callback = function()
    require("lint").try_lint("actionlint")
  end,
  group = lintGrp,
})

-- Initialize LSP client cache for statusline
state.lsp_client_cache = {}

create_autocmd({ "LspAttach" }, {
  group = lspGrp,
  callback = function(ev)
    -- Cache LSP clients for statusline performance
    state.lsp_client_cache[ev.buf] = vim.lsp.get_clients({ bufnr = ev.buf })

    local bufopts = function(newOpts)
      if newOpts == nil then
        newOpts = {}
      end
      local opts = { noremap = true, silent = true, buffer = ev.buf }
      return vim.tbl_deep_extend("force", opts, newOpts)
    end

    local client_id = ev.data.client_id
    local map_if = function(capability, mode, key, rhs, opts)
      on_lsp_capability(capability, mode, key, rhs, opts, client_id)
    end

    local client = vim.lsp.get_client_by_id(client_id)
    if client and client.name == "copilot" then
      reload_blink_provider("copilot")
    end
    ---Enable or disable LSP inlay hints for a buffer, with backwards compatibility for API changes.
    ---@param buf integer
    ---@param enable boolean
    local function set_inlay_hint(buf, enable)
      local ih = vim.lsp.inlay_hint
      if not ih or type(ih.enable) ~= "function" then
        return
      end
      if not pcall(ih.enable, buf, enable) then
        pcall(ih.enable, enable, buf)
      end
    end

    ---Check whether inlay hints are currently enabled for a buffer.
    ---@param buf integer
    ---@return boolean
    local function inlay_hint_enabled(buf)
      local ih = vim.lsp.inlay_hint
      if not ih or type(ih.is_enabled) ~= "function" then
        return false
      end
      local ok, result = pcall(ih.is_enabled, buf)
      return ok and result or false
    end

    if client and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
      set_inlay_hint(ev.buf, true)
    end

    -- Enable document highlight
    if client and client.server_capabilities.documentHighlightProvider then
      local highlight_grp = create_group("LspDocumentHighlight_" .. ev.buf)
      create_autocmd({ "CursorHold", "CursorHoldI" }, {
        buffer = ev.buf,
        group = highlight_grp,
        callback = function()
          vim.lsp.buf.document_highlight()
        end,
      })
      create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = ev.buf,
        group = highlight_grp,
        callback = function()
          vim.lsp.buf.clear_references()
        end,
      })
    end

    -- Enable codelens
    if client and client.server_capabilities.codeLensProvider then
      vim.lsp.codelens.enable(true, { bufnr = ev.buf })
      create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
        buffer = ev.buf,
        group = create_group("LspCodelens_" .. ev.buf),
        callback = function()
          vim.lsp.codelens.refresh({ bufnr = ev.buf })
        end,
      })
    end

    ---Toggle inlay hints for the attached buffer.
    ---@return nil
    local function toggle_inlay_hints()
      if not vim.lsp.inlay_hint then
        return
      end
      local enabled = inlay_hint_enabled(ev.buf)
      set_inlay_hint(ev.buf, not enabled)
    end

    map_if("declarationProvider", "n", "gD", vim.lsp.buf.declaration, bufopts({ desc = "[G]o to [D]eclaration" }))
    map_if(
      "definitionProvider",
      "n",
      "gd",
      "<cmd>FzfLua lsp_definitions<cr>",
      bufopts({ desc = "[G]o to [d]efinition" })
    )
    map_if("referencesProvider", "n", "gr", "<cmd>FzfLua lsp_references<cr>", bufopts({ desc = "References" }))
    map_if("signatureHelpProvider", "n", "<C-k>", vim.lsp.buf.signature_help, bufopts({ desc = "Signature help" }))
    map_if(
      "implementationProvider",
      "n",
      "gi",
      "<cmd>FzfLua lsp_implementations<cr>",
      bufopts({ desc = "[G]o to [i]mplementation" })
    )
    map_if(
      "typeDefinitionProvider",
      "n",
      "<leader>ctd",
      vim.lsp.buf.type_definition,
      bufopts({ desc = "[T]ype [D]efinition" })
    )
    map_if(
      "codeActionProvider",
      "n",
      "<leader>ca",
      "<cmd>FzfLua lsp_code_actions<cr>",
      bufopts({ desc = "[C]ode [a]ctions" })
    )
    map_if("renameProvider", "n", "<leader>cr", vim.lsp.buf.rename, bufopts({ desc = "[C]ode [R]ename" }))

    utils.map("n", "K", vim.lsp.buf.hover, bufopts({ desc = "Details" }))
    utils.map("n", "<leader>cti", toggle_inlay_hints, bufopts({ desc = "[C]ode [T]oggle [I]nlay hints" }))
    utils.map("n", "<leader>cl", vim.lsp.codelens.run, bufopts({ desc = "[C]ode [L]ens run" }))
  end,
})

create_autocmd("LspDetach", {
  group = lspGrp,
  callback = function(ev)
    state.lsp_client_cache[ev.buf] = nil
  end,
})

vim.diagnostic.config({
  float = {
    border = "rounded",
  },
})

local diag_group = create_group("OneBeerDiagnostics")
create_autocmd("CursorHold", {
  group = diag_group,
  callback = function()
    if vim.g.onebeer_inline_diagnostics_enabled ~= false then
      return
    end
    vim.diagnostic.open_float(nil, { focus = false, scope = "cursor" })
  end,
})

---Open the current LSP log file in a new buffer.
---@return nil
local function inspect_log()
  local path = nil
  if vim.lsp and vim.lsp.get_log_path then
    path = vim.lsp.get_log_path()
  elseif vim.lsp and vim.lsp.log_path then
    path = vim.lsp.log_path()
  end
  path = path or (vim.fn.stdpath("state") .. "/lsp.log")
  if path == "" then
    vim.notify("No LSP log file available", vim.log.levels.WARN, { title = "InspectLog" })
    return
  end
  vim.cmd(("edit %s"):format(vim.fn.fnameescape(path)))
end

create_command("InspectLog", inspect_log, { desc = "Open the LSP log file" })

local statusGroup = create_group("OneBeerStatusColumn")
local miniFilesGroup = create_group("OneBeerMiniFiles")
---Blank the statuscolumn when entering insert mode unless manually disabled.
---@return nil
local function hide_statuscolumn()
  if vim.g.onebeer_statuscolumn_manual_off then
    return
  end
  if vim.o.statuscolumn ~= "" then
    vim.g.onebeer_statuscolumn_cached = vim.o.statuscolumn
    vim.o.statuscolumn = ""
  end
end

---Restore the previous statuscolumn when leaving insert mode.
---@return nil
local function restore_statuscolumn()
  if vim.g.onebeer_statuscolumn_manual_off then
    return
  end
  if vim.o.statuscolumn == "" then
    vim.o.statuscolumn = vim.g.onebeer_statuscolumn_cached or vim.g.onebeer_statuscolumn_expr or ""
  end
end

create_autocmd("InsertEnter", {
  group = statusGroup,
  callback = hide_statuscolumn,
})

create_autocmd("InsertLeave", {
  group = statusGroup,
  callback = restore_statuscolumn,
})

create_autocmd("User", {
  group = miniFilesGroup,
  pattern = "MiniFilesExplorerOpen",
  callback = function()
    if not vim.g.onebeer_minifiles_shortmess then
      vim.g.onebeer_minifiles_shortmess = vim.o.shortmess
    end
    if not vim.o.shortmess:find("F") then
      vim.opt.shortmess:append("F")
    end
  end,
})

create_autocmd("User", {
  group = miniFilesGroup,
  pattern = "MiniFilesExplorerClose",
  callback = function()
    if vim.g.onebeer_minifiles_shortmess then
      vim.o.shortmess = vim.g.onebeer_minifiles_shortmess
      vim.g.onebeer_minifiles_shortmess = nil
    end
  end,
})

local writeAudit = create_group("OneBeerWriteAudit")
local uv = vim.uv or vim.loop
create_autocmd("BufWritePre", {
  group = writeAudit,
  callback = function(ev)
    if not uv then
      return
    end
    vim.b[ev.buf].onebeer_write_start = uv.hrtime()
  end,
})

create_autocmd("BufWritePost", {
  group = writeAudit,
  callback = function(ev)
    local start = vim.b[ev.buf].onebeer_write_start
    if not start or not uv then
      return
    end
    local elapsed = (uv.hrtime() - start) / 1e9
    if elapsed > 1 then
      local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ev.buf), ":~:.")
      vim.notify(("Saved %s in %.2fs"):format(name, elapsed), vim.log.levels.INFO, { title = "Write latency" })
    end
  end,
})

-- Remove trailing whitespace on save
local trimGrp = create_group("TrimWhitespace")
create_autocmd("BufWritePre", {
  group = trimGrp,
  callback = function()
    if vim.g.disable_trim_whitespace then
      return
    end

    local view = vim.fn.winsaveview()
    pcall(function()
      vim.cmd([[%s/\s\+$//e]])
    end)
    vim.fn.winrestview(view)
  end,
})

create_command("TrimWhitespaceToggle", function()
  vim.g.disable_trim_whitespace = not vim.g.disable_trim_whitespace
  local status = vim.g.disable_trim_whitespace and "disabled" or "enabled"
  vim.notify("Trim trailing whitespace " .. status, vim.log.levels.INFO)
end, { desc = "Toggle trim trailing whitespace on save" })
