local treesitter_languages = {
  'bash',
  'c',
  'c_sharp',
  'css',
  'diff',
  'html',
  'javascript',
  'json',
  'lua',
  'luadoc',
  'markdown',
  'markdown_inline',
  'query',
  'scss',
  'tsx',
  'typescript',
  'vim',
  'vimdoc',
}

return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = function()
      local treesitter = require 'nvim-treesitter'
      treesitter.install(treesitter_languages):wait(300000)
      treesitter.update(treesitter_languages):wait(300000)
    end,
    config = function()
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('treesitter-features', { clear = true }),
        pattern = {
          'c',
          'cs',
          'css',
          'diff',
          'help',
          'html',
          'javascript',
          'javascriptreact',
          'json',
          'lua',
          'markdown',
          'query',
          'scss',
          'sh',
          'typescript',
          'typescriptreact',
          'vim',
        },
        callback = function()
          if pcall(vim.treesitter.start) then
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
