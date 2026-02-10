---JSON-to-TypeScript helper for OneBeer tooling (jq + quicktype).
---@class OneBeerJsonToTs
local M = {}

---Convert JSON (selection or buffer) into TypeScript types via quicktype.
---@return nil
function M.generate()
  local filename = vim.fn.input("Output filename (e.g. response.ts): ")
  if filename == "" or filename == nil then
    vim.notify("Aborted: Please provide a filename", vim.log.levels.ERROR)
    return
  end
  local name = vim.fn.input("Root type name (e.g. ApiResponse): ", "ApiResponse")

  local mode = vim.fn.mode()
  local lines
  if mode:match("[vV]") then
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    lines = vim.fn.getline(start_pos[2], end_pos[2])
  else
    lines = vim.fn.getline(1, "$")
  end
  local json = table.concat(lines, "\n")

  local cmd = string.format(
    "jq '.' | npx quicktype --lang ts --just-types --top-level %s --src - > %s",
    vim.fn.shellescape(name, true),
    vim.fn.shellescape(filename, true)
  )

  local handle = io.popen(cmd, "w")
  if not handle then
    vim.notify("Failed to run quicktype. Ensure jq and quicktype are installed (e.g. `npm i -g quicktype`).", vim.log.levels.ERROR)
    return
  end
  handle:write(json)
  handle:close()

  vim.notify("TypeScript types written to " .. filename, vim.log.levels.INFO, { title = "JSON → TS" })
end

return M
