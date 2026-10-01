-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local root = vim.fs.root(vim.fn.getcwd(), "node_modules")
local ok, pkg = pcall(vim.fn.readfile, root and root .. "/node_modules/typescript/package.json" or "")
if ok and tonumber(vim.json.decode(table.concat(pkg)).version:match("^(%d+)")) >= 7 then
  vim.g.lazyvim_ts_lsp = "tsc"
end
