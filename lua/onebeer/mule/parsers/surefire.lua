---@class onebeer.mule.SurefireParser
local M = {}

---@class onebeer.mule.TestResult
---@field name string
---@field classname string
---@field status "passed"|"failed"|"errored"|"skipped"
---@field message string|nil

---@param attrs string
---@param name string
---@return string
local function attr(attrs, name)
  return attrs:match("^%s*" .. name .. "=[\"']([^\"']*)[\"']")
    or attrs:match("%s+" .. name .. "=[\"']([^\"']*)[\"']")
    or ""
end

---@param body string
---@param tag string
---@return string|nil
local function child_message(body, tag)
  local attrs, content = body:match("<" .. tag .. "([^>]*)>(.-)</" .. tag .. ">")
  if attrs then
    return attr(attrs, "message") ~= "" and attr(attrs, "message") or vim.trim(content)
  end
  attrs = body:match("<" .. tag .. "([^>]*)/>")
  if attrs then
    return attr(attrs, "message")
  end
  return nil
end

---@param path string
---@return onebeer.mule.TestResult[]
function M.parse_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return {}
  end

  local xml = table.concat(lines, "\n")
  local results = {}

  for attrs, body in xml:gmatch("<testcase([^>]*)>(.-)</testcase>") do
    local status = "passed"
    local message
    if body:find("<failure", 1, true) then
      status = "failed"
      message = child_message(body, "failure")
    elseif body:find("<error", 1, true) then
      status = "errored"
      message = child_message(body, "error")
    elseif body:find("<skipped", 1, true) then
      status = "skipped"
      message = child_message(body, "skipped")
    end

    results[#results + 1] = {
      classname = attr(attrs, "classname"),
      message = message,
      name = attr(attrs, "name"),
      status = status,
    }
  end

  for attrs in xml:gmatch("<testcase([^>]*)/>") do
    results[#results + 1] = {
      classname = attr(attrs, "classname"),
      name = attr(attrs, "name"),
      status = "passed",
    }
  end

  return results
end

---@param paths string[]
---@return onebeer.mule.TestResult[]
function M.parse_files(paths)
  local results = {}
  for _, path in ipairs(paths) do
    vim.list_extend(results, M.parse_file(path))
  end
  return results
end

return M
