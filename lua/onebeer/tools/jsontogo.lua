---JSON-to-Go helper for OneBeer tooling (jq + gojson).
---@class OneBeerJsonToGo
local M = {}

---Convert visually selected JSON into Go structs via jq + gojson.
---@return nil
function M.generate()
  local filename = vim.fn.input("Output filename (e.g. response.go): ")
  if filename == "" or filename == nil then
    vim.notify("Aborted: Please provide a filename", vim.log.levels.ERROR)
    return
  end
  local name = vim.fn.input("Root struct name (e.g. Response): ")
  local pkg = vim.fn.input("Package name: ", "api")

  local mode = vim.fn.mode()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines
  if mode == "v" or mode == "V" then
    lines = vim.fn.getline(start_pos[2], end_pos[2])
  else
    lines = vim.fn.getline(1, "$")
  end
  local json = table.concat(lines, "\n")

  local cmd = string.format("jq -c '.' | gojson -name %s -pkg %s > %s", name, pkg, filename)

  local handle = io.popen(cmd, "w")
  if not handle then
    print("Failed to run pipeline. Ensure jq and gojson are installed.")
    return
  end
  handle:write(json)
  handle:close()

  print("Go structs written to " .. filename)
end

return M
