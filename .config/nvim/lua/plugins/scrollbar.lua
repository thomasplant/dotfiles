return {
  {
    'petertriho/nvim-scrollbar',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'lewis6991/gitsigns.nvim' },
    config = function()
      local function set_git_mark_highlights()
        local colors = vim.o.background == 'light'
            and {
              ScrollbarGitAdd = '#79740e',
              ScrollbarGitChange = '#b57614',
              ScrollbarGitDelete = '#9d0006',
            }
          or {
            ScrollbarGitAdd = '#b8bb26',
            ScrollbarGitChange = '#fabd2f',
            ScrollbarGitDelete = '#fb4934',
          }

        for group, color in pairs(colors) do
          vim.api.nvim_set_hl(0, group, { fg = color, bold = true })
        end
      end

      require('scrollbar').setup {
        marks = {
          GitAdd = { text = '▐' },
          GitChange = { text = '▐' },
          GitDelete = { text = '▐' },
        },
      }
      require('scrollbar.handlers.gitsigns').setup()

      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('scrollbar-git-highlights', { clear = true }),
        callback = set_git_mark_highlights,
      })
      set_git_mark_highlights()
    end,
  },
}
