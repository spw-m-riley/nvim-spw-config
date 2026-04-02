---Internal OneBeer tooling commands (cheatsheet/doctor helpers).
---@module "onebeer.tools.commands"
local create_command = require("onebeer.autocmds.helpers").create_command

---Open a scratch floating window with the provided lines.
---@param title string
---@param lines string[]
local function open_float(title, lines)
  lines = (#lines == 0) and { "" } or lines
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(vim.o.columns - 4, width + 4)
  local height = math.min(vim.o.lines - 4, #lines + 2)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "onebeer_info"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
  })
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, silent = true })
end

---Open a treesitter inspector, falling back to playground helpers when available.
---@return nil
local function inspect_tree()
  if vim.treesitter and vim.treesitter.inspect_tree then
    vim.treesitter.inspect_tree()
    return
  end
  local ok, playground = pcall(require, "nvim-treesitter.playground")
  if ok and playground.inspect_tree then
    playground.inspect_tree()
    return
  end
  vim.notify("Treesitter inspect support not available", vim.log.levels.WARN, { title = "InspectTree" })
end

---Show highlight groups under the cursor using :Inspect.
---@return nil
local function inspect_syntax()
  vim.cmd("Inspect")
end

---@type string[]
local help_lines = {
  "OneBeer Quick Help",
  "------------------",
  "Need the full tour? :h onebeer has you covered",
  "Leader aa/ap/... -> Sidekick + Copilot CLI",
  "Leader a         -> Align multicursors",
  "Leader c         -> Code actions, diagnostics, Copilot, SSR",
  "Leader d         -> Debugger (nvim-dap)",
  "Leader f         -> Mini.files explorer",
  "Leader g         -> Waystone marks",
  "Leader jg / jt   -> JSON generators",
  "Leader l         -> Gitsigns hunk actions",
  "Leader m         -> Move lines",
  "Leader o         -> GitHub via Octo",
  "Leader p         -> Precognition hints",
  "Leader q         -> Trouble + sessions",
  "Leader s         -> Search suite (fzf-lua)",
  "Leader t         -> Tests",
  "Leader u         -> UI/help/doctor/log/toggles",
  "Leader v         -> Git / VCS helpers",
  "Leader uu        -> Undotree",
  "Leader x         -> Multicursor remove",
  "[d / ]d          -> Prev/Next diagnostic",
  "[h / ]h          -> Prev/Next hunk",
  "[r / ]r          -> Prev/Next reference",
  "ai / ii          -> Snacks scope text-objects",
  "<leader>uh       -> Reopen this quick guide",
  "<leader>ud       -> Run OneBeerDoctor",
}

local exec2 = vim.api.nvim_exec2
if not exec2 then
  exec2 = function(cmd, _)
    local ok, err = pcall(vim.cmd, cmd)
    if not ok then
      error(err)
    end
    return { output = "" }
  end
end

---Capture the output of a normal-mode command.
---@param cmd string
---@return string[]
local function capture(cmd)
  local ok, result = pcall(exec2, cmd, { output = true })
  if not ok then
    return {
      ("[%s] Error: %s"):format(cmd, result),
    }
  end
  local output = vim.trim(result.output or "")
  if output == "" then
    return { ("[%s] No output"):format(cmd) }
  end
  local lines = vim.split(output, "\n", { plain = true, trimempty = true })
  table.insert(lines, 1, ("[%s]"):format(cmd))
  return lines
end

---Aggregate health/debug outputs and show them in a floating picker or window.
---@return nil
local function doctor()
  local commands = {
    "checkhealth",
    "lua print(vim.inspect(vim.pack.get(nil, { info = false })))",
    "LspInfo",
  }
  local collected = {}
  for _, cmd in ipairs(commands) do
    local lines = capture(cmd)
    vim.list_extend(collected, lines)
    table.insert(collected, "")
  end
  local fzf_ok, fzf = pcall(require, "fzf-lua")
  if not fzf_ok then
    open_float("OneBeer Doctor", collected)
    return
  end
  local tmpfile = vim.fn.tempname() .. "-onebeer-doctor.log"
  vim.fn.writefile(collected, tmpfile)
  local entries = {}
  for idx, line in ipairs(collected) do
    entries[idx] = string.format("%05d │ %s", idx, line)
  end
  local preview_cmd = table.concat({
    "awk '",
    "NR>=({1}-20)&&NR<=({1}+40)",
    '{ printf("%5d │ %s\\n", NR, $0) }',
    string.format("' %s", vim.fn.shellescape(tmpfile)),
  })
  fzf.fzf_exec(entries, {
    prompt = "Doctor> ",
    fzf_opts = {
      ["--ansi"] = "",
      ["--preview-window"] = "down:70%",
      ["--preview"] = preview_cmd,
    },
    actions = {
      ["default"] = function(sel)
        if not sel or not sel[1] then
          return
        end
        local line_nr = sel[1]:match("^(%d+)")
        vim.cmd(("tabnew %s"):format(vim.fn.fnameescape(tmpfile)))
        local ln = tonumber(line_nr) or 1
        vim.api.nvim_win_set_cursor(0, { ln, 0 })
      end,
    },
  })
end

---Render the keymap cheatsheet inside a float.
---@return nil
local function help()
  open_float("OneBeer Help", help_lines)
end

create_command("InspectTree", inspect_tree, { desc = "Inspect Treesitter tree for current buffer" })
create_command("InspectSyntax", inspect_syntax, { desc = "Inspect highlight groups at cursor" })
create_command("OneBeerHelp", help, { desc = "Show OneBeer keymap cheatsheet" })
create_command("OneBeerDoctor", doctor, { desc = "Run core diagnostics (checkhealth/vim.pack/LspInfo)" })

return {}
