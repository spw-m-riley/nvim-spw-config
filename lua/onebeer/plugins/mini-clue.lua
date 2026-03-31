---@module "lazy"
---@type LazySpec
return {
  "echasnovski/mini.clue",
  version = "*",
  event = "VeryLazy",
  config = function()
    local miniclue = require("mini.clue")

    miniclue.setup({
      window = {
        delay = 500, -- Show clue window after 500ms
        config = {
          width = "auto",
          border = "rounded",
        },
      },
      clues = {
        -- custom clues
        { mode = "n", keys = "<Leader>a", desc = "Sidekick" },
        { mode = "n", keys = "<Leader>f", desc = "[F]iles" },
        { mode = "n", keys = "<Leader>b", desc = "[B]uffers" },
        { mode = "n", keys = "<Leader>c", desc = "[C]ode" },
        { mode = "n", keys = "<Leader>cc", desc = "CodeCompanion" },
        { mode = "n", keys = "<Leader>d", desc = "[D]ebugger" },
        { mode = "n", keys = "<Leader>jg", desc = "JSON to Go" },
        { mode = "n", keys = "<Leader>jt", desc = "JSON to TypeScript" },
        { mode = "n", keys = "<Leader>l", desc = "[L]ine hunks" },
        { mode = "n", keys = "<Leader>g", desc = "Waystone" },
        { mode = "n", keys = "<Leader>m", desc = "[M]ove lines" },
        { mode = "n", keys = "<Leader>p", desc = "[P]recognition" },
        { mode = "n", keys = "<Leader>q", desc = "[Q]uickfix & Sessions" },
        { mode = "n", keys = "<Leader>qd", desc = "Stop session save" },
        { mode = "n", keys = "<Leader>qs", desc = "Restore session" },
        { mode = "n", keys = "<Leader>qS", desc = "Restore last session" },
        { mode = "n", keys = "<Leader>qf", desc = "Diagnostics list" },
        { mode = "n", keys = "<Leader>s", desc = "[S]earch" },
        { mode = "n", keys = "<Leader>sd", desc = "[S]nacks [D]ashboard" },
        { mode = "n", keys = "<Leader>sv", desc = "[S]earch [V]cs" },
        { mode = "n", keys = "<Leader>v", desc = "[V]CS helpers" },
        { mode = "n", keys = "<Leader>vg", desc = "Open in remote" },
        { mode = "n", keys = "<Leader>vB", desc = "Inline blame" },
        { mode = "n", keys = "<Leader>u", desc = "[U]I" },
        { mode = "n", keys = "<Leader>um", desc = "[U]I [M]essages" },
        { mode = "n", keys = "<Leader>un", desc = "[U]I [N]otifications" },
        { mode = "n", keys = "<Leader>ul", desc = "[U]I [L]og file" },
        { mode = "n", keys = "<Leader>uh", desc = "[U]I [H]elp" },
        { mode = "n", keys = "<Leader>ud", desc = "[U]I [D]octor" },
        { mode = "n", keys = "<Leader>us", desc = "[U]I toggle statuscolumn" },
        { mode = "n", keys = "<Leader>uS", desc = "[U]I toggle smooth scroll" },
        { mode = "n", keys = "<Leader>uv", desc = "[U]I toggle diagnostics virtual text" },
        { mode = "n", keys = "<Leader>uw", desc = "[U]I toggle reference overlay" },
        { mode = "n", keys = "<Leader>t", desc = "[T]ranspose cursors" },
        { mode = "n", keys = "<Leader>T", desc = "[T]ranspose cursors (reverse)" },
        { mode = "n", keys = "<Leader>x", desc = "Multicursor remove" },
        { mode = "n", keys = "gnn", desc = "TS: init selection" },
        { mode = "n", keys = "grn", desc = "TS: expand selection" },
        { mode = "n", keys = "gns", desc = "TS: expand scope" },
        { mode = "n", keys = "grm", desc = "TS: shrink selection" },
        { mode = "n", keys = "]r", desc = "Next reference" },
        { mode = "n", keys = "[r", desc = "Prev reference" },
        { mode = "o", keys = "ai", desc = "Scope (outer)" },
        { mode = "o", keys = "ii", desc = "Scope (inner)" },
        { mode = "x", keys = "ai", desc = "Scope (outer)" },
        { mode = "x", keys = "ii", desc = "Scope (inner)" },

        -- builtin clues
        miniclue.gen_clues.builtin_completion(),
        miniclue.gen_clues.g(),
        miniclue.gen_clues.marks(),
        miniclue.gen_clues.registers(),
        miniclue.gen_clues.windows(),
        miniclue.gen_clues.z(),
      },
      triggers = {
        -- Leader triggers
        { mode = "n", keys = "<Leader>" },
        { mode = "x", keys = "<Leader>" },

        -- `g` key
        { mode = "n", keys = "g" },
        { mode = "x", keys = "g" },

        -- Marks
        { mode = "n", keys = "'" },
        { mode = "n", keys = "`" },
        { mode = "x", keys = "'" },
        { mode = "x", keys = "`" },

        -- Registers
        { mode = "n", keys = '"' },
        { mode = "x", keys = '"' },
        { mode = "i", keys = "<C-r>" },
        { mode = "c", keys = "<C-r>" },

        -- Window commands
        { mode = "n", keys = "<C-w>", desc = "[W]indows" },

        -- `z` key
        { mode = "n", keys = "z" },
        { mode = "x", keys = "z" },
      },
    })
  end,
}
