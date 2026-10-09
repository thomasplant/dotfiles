-- The pinned Tree-sitter main branch requires Neovim 0.12 or newer.
if vim.fn.has 'nvim-0.12' == 0 then
  error 'This Neovim config requires Neovim 0.12 or newer.'
end

vim.loader.enable()

require 'config.options'
require 'config.keymaps'
require 'config.autocmds'
require 'config.lazy'
