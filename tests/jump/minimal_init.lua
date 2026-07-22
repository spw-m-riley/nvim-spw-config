local root = vim.fn.getcwd()

vim.loader.enable(false)
vim.opt.runtimepath:prepend(root)
package.path = table.concat({
  root .. "/lua/?.lua",
  root .. "/lua/?/init.lua",
  package.path,
}, ";")

vim.o.swapfile = false
vim.o.undofile = false
