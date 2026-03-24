local M = {}

---@param node TSNode|TSNode[]?
---@return TSNode?
local function unwrap_capture(node)
  if type(node) == "table" then
    return node[1]
  end
  return node
end

function M.apply()
  local search = require("ssr.search")
  if search._onebeer_capture_compat_applied then
    return
  end

  local extmark_range = search.ExtmarkRange
  local new = extmark_range.new

  extmark_range.new = function(ns, buf, node)
    return new(ns, buf, unwrap_capture(node))
  end

  search._onebeer_capture_compat_applied = true
end

return M
