local M = {}

local ns = vim.api.nvim_create_namespace("onebeer_jump")
local rendered_buffers = {}

local function define_highlights()
  vim.api.nvim_set_hl(0, "OneBeerJumpLabel", { default = true, link = "IncSearch" })
  vim.api.nvim_set_hl(0, "OneBeerJumpMatch", { default = true, link = "Search" })
end

---@return integer
function M.namespace()
  return ns
end

function M.clear()
  for buf in pairs(rendered_buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end
  end
  rendered_buffers = {}
end

---@param targets onebeer.jump.Target[]
function M.show(targets)
  M.clear()
  define_highlights()

  for _, target in ipairs(targets) do
    if target.label and vim.api.nvim_buf_is_valid(target.buf) then
      vim.api.nvim_buf_set_extmark(target.buf, ns, target.row - 1, target.col, {
        virt_text = { { target.label, "OneBeerJumpLabel" } },
        virt_text_pos = "overlay",
        virt_text_hide = true,
        hl_mode = "combine",
        priority = 200,
      })
      rendered_buffers[target.buf] = true
    end
  end
end

return M
