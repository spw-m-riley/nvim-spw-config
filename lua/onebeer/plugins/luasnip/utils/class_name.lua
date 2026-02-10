local caps = require("plugins.luasnip.utils.capitalise")

local class_name = function()
  local curr_buffer_name = vim.api.nvim_buf_get_name(0)
  local path_parts = vim.split(curr_buffer_name, "/", {})
  local file_parts = vim.split(path_parts[#path_parts], ".", {})
  return caps(file_parts[1]) .. caps(file_parts[2])
end

return class_name
