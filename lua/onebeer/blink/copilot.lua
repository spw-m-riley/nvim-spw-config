local api = require("copilot.api")
local client = require("copilot.client")
local format = require("blink-cmp-copilot.format")
local util = require("copilot.util")

---@class onebeer.blink.copilot.Source
local M = {}

local function empty_response()
  return {
    is_incomplete_forward = true,
    is_incomplete_backward = true,
    items = {},
  }
end

---@return vim.lsp.Client|nil
local function get_client()
  if not select(1, util.should_attach(0)) then
    return nil
  end

  local current = client.get()
  if not current or not current.initialized then
    return nil
  end

  if not client.buf_is_attached(0) then
    return nil
  end

  return current
end

function M.get_trigger_characters()
  return { "." }
end

function M:enabled()
  return get_client() ~= nil
end

function M:get_completions(context, callback)
  local copilot = get_client()
  if not copilot then
    return callback(empty_response())
  end

  local respond_callback = function(err, response)
    if err or not response or not response.completions then
      return callback(empty_response())
    end

    local items = vim.tbl_map(function(item)
      return format.format_item(item, context)
    end, vim.tbl_values(response.completions))

    return callback({
      is_incomplete_forward = false,
      is_incomplete_backward = false,
      items = items,
    })
  end

  api.get_completions(copilot, util.get_doc_params(), respond_callback)
end

function M:new()
  return setmetatable({}, { __index = M })
end

return M
