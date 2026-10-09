-- Core mappings. Plugin modules are required only when a mapping is used.
vim.keymap.set('i', 'kj', '<Esc>')
vim.keymap.set('i', '<C-BS>', '<C-W>', { noremap = true, desc = 'Delete word backward' })

vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

local function highlight_word_under_cursor()
  local word = vim.fn.expand '<cword>'
  if word == '' then
    return
  end
  vim.fn.setreg('/', [[\<]] .. vim.fn.escape(word, [[\/]]) .. [[\>]])
  vim.o.hlsearch = true
end

vim.keymap.set('n', '*', highlight_word_under_cursor, { desc = 'Highlight word under cursor (no jump)' })

vim.keymap.set('n', '<2-LeftMouse>', highlight_word_under_cursor, { desc = 'Highlight word under cursor (no jump)' })

vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- <C-h/j/k/l> window moves come from vim-tmux-navigator (lua/plugins/tmux-navigator.lua).
vim.keymap.set('n', '<C-y>', '<cmd>let @+ = expand("%:p")<CR>', { desc = 'Copy file path to clipboard' })

vim.keymap.set('n', '<A-j>', '<cmd>m .+1<CR>==', { desc = 'Move line down' })
vim.keymap.set('n', '<A-k>', '<cmd>m .-2<CR>==', { desc = 'Move line up' })
vim.keymap.set('i', '<A-j>', '<Esc><cmd>m .+1<CR>==gi', { desc = 'Move line down' })
vim.keymap.set('i', '<A-k>', '<Esc><cmd>m .-2<CR>==gi', { desc = 'Move line up' })
vim.keymap.set('v', '<A-j>', ":m '>+1<CR>gv=gv", { desc = 'Move selection down' })
vim.keymap.set('v', '<A-k>', ":m '<-2<CR>gv=gv", { desc = 'Move selection up' })

vim.keymap.set('n', '<leader>d', vim.diagnostic.open_float, { desc = 'Show line [D]iagnostics' })

-- Buffer controls are independent of Telescope.
vim.keymap.set('n', '<S-l>', '<cmd>bnext<CR>')
vim.keymap.set('n', '<S-h>', '<cmd>bprevious<CR>')
vim.keymap.set('n', '<leader>c', function()
  require('mini.bufremove').delete(0, false)
end, { desc = 'Buffer Delete' })
vim.keymap.set('n', '<leader>C', function()
  local current = vim.api.nvim_get_current_buf()
  local all_deleted = true
  local buffers = vim.tbl_filter(function(buffer)
    return vim.api.nvim_buf_is_valid(buffer) and vim.bo[buffer].buflisted
  end, vim.api.nvim_list_bufs())

  for _, buffer in ipairs(buffers) do
    if buffer ~= current then
      all_deleted = require('mini.bufremove').delete(buffer, false) == true and all_deleted
    end
  end
  if vim.api.nvim_buf_is_valid(current) and vim.bo[current].buflisted then
    all_deleted = require('mini.bufremove').delete(current, false) == true and all_deleted
  end
  if all_deleted then
    require('mini.starter').open(vim.api.nvim_get_current_buf())
  end
end, { desc = 'Delete All Buffers' })
