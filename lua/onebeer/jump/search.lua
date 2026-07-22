local labels = require("onebeer.jump.labels")
local render = require("onebeer.jump.render")
local targets = require("onebeer.jump.targets")

local M = {}

local function enabled()
  return require("onebeer.jump").search_enabled()
end

function M.clear()
  render.clear()
end

function M.update()
  local command = vim.fn.getcmdtype()
  if not enabled() or (command ~= "/" and command ~= "?") then
    M.clear()
    return
  end

  local pattern = vim.fn.getcmdline()
  if pattern == "" then
    M.clear()
    return
  end

  local items = targets.search(pattern)
  if command == "?" then
    items = vim.fn.reverse(items)
  end
  local generated = labels.generate(#items)
  for index, target in ipairs(items) do
    target.label = generated[index]
  end
  render.show(items)
end

return M
