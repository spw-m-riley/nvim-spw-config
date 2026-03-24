---JSON-to-Go helper for OneBeer tooling (jq + gojson).
---@class OneBeerJsonToGo
local M = {}

local title = "JSON → Go"

---@param mode string
---@return string[]
local function selected_lines(mode)
  if mode == "v" or mode == "V" then
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    return vim.fn.getline(start_pos[2], end_pos[2])
  end

  return vim.fn.getline(1, "$")
end

---@param cmd string[]
---@param input string
---@return vim.SystemCompleted|nil, string|nil
local function run_command(cmd, input)
  local ok, system_obj = pcall(vim.system, cmd, { stdin = input, text = true })
  if not ok then
    return nil, system_obj
  end

  local result = system_obj:wait()
  if result.code ~= 0 then
    local err = vim.trim((result.stderr ~= "" and result.stderr) or result.stdout or ("exit code " .. result.code))
    return nil, err
  end

  return result, nil
end

---Convert visually selected JSON into Go structs via jq + gojson.
---@return nil
function M.generate()
  local filename = vim.fn.input("Output filename (e.g. response.go): ")
  if filename == "" or filename == nil then
    vim.notify("Aborted: Please provide a filename", vim.log.levels.ERROR, { title = title })
    return
  end

  local name = vim.fn.input("Root struct name (e.g. Response): ")
  local pkg = vim.fn.input("Package name: ", "api")

  local json = table.concat(selected_lines(vim.fn.mode()), "\n")

  local normalized, normalize_err = run_command({ "jq", "-c", "." }, json)
  if not normalized then
    vim.notify("Failed to normalize JSON with jq: " .. normalize_err, vim.log.levels.ERROR, { title = title })
    return
  end

  local generated, generate_err = run_command({ "gojson", "-name", name, "-pkg", pkg }, normalized.stdout or "")
  if not generated then
    vim.notify(
      "Failed to generate Go structs. Ensure jq and gojson are installed: " .. generate_err,
      vim.log.levels.ERROR,
      { title = title }
    )
    return
  end

  local write_ok, write_err =
    pcall(vim.fn.writefile, vim.split(generated.stdout or "", "\n", { plain = true }), filename)
  if not write_ok then
    vim.notify("Failed to write " .. filename .. ": " .. write_err, vim.log.levels.ERROR, { title = title })
    return
  end

  vim.notify("Go structs written to " .. filename, vim.log.levels.INFO, { title = title })
end

return M
