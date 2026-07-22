local M = {}

---@param count integer
---@param alphabet? string
---@return string[]
function M.generate(count, alphabet)
  alphabet = alphabet or "asdfghjklqwertyuiopzxcvbnm"
  if count <= 0 then
    return {}
  end

  local keys = vim.fn.strchars(alphabet)
  assert(keys > 1, "jump label alphabet must contain at least two characters")

  local width = 1
  local capacity = keys
  while capacity < count do
    width = width + 1
    capacity = capacity * keys
  end

  local labels = {}
  for index = 0, count - 1 do
    local value = index
    local chars = {}
    for position = width, 1, -1 do
      local digit = value % keys
      chars[position] = vim.fn.strcharpart(alphabet, digit, 1)
      value = math.floor(value / keys)
    end
    labels[#labels + 1] = table.concat(chars)
  end
  return labels
end

return M
