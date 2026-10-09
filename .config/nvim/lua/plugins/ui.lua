return {
  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
    opts = {
      delay = 0,
      icons = {
        mappings = vim.g.have_nerd_font,
        keys = vim.g.have_nerd_font and {} or {
          Up = '<Up> ',
          Down = '<Down> ',
          Left = '<Left> ',
          Right = '<Right> ',
          C = '<C-…> ',
          M = '<M-…> ',
          D = '<D-…> ',
          S = '<S-…> ',
          CR = '<CR> ',
          Esc = '<Esc> ',
          ScrollWheelDown = '<ScrollWheelDown> ',
          ScrollWheelUp = '<ScrollWheelUp> ',
          NL = '<NL> ',
          BS = '<BS> ',
          Space = '<Space> ',
          Tab = '<Tab> ',
          F1 = '<F1>',
          F2 = '<F2>',
          F3 = '<F3>',
          F4 = '<F4>',
          F5 = '<F5>',
          F6 = '<F6>',
          F7 = '<F7>',
          F8 = '<F8>',
          F9 = '<F9>',
          F10 = '<F10>',
          F11 = '<F11>',
          F12 = '<F12>',
        },
      },

      spec = {
        { '<leader>s', group = '[S]earch' },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>g', group = '[G]it', mode = { 'n', 'v' } },
        { '<leader>e', group = 'NeoTree' },
        { '<leader>b', group = '[B]uffer Control' },
      },
    },
  },

  { -- You can easily change to a different colorscheme.
    'ellisonleao/gruvbox.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      local function set_diff_highlights()
        local highlights = vim.o.background == 'light'
            and {
              DiffAdd = { bg = '#b4d29c' },
              DiffDelete = { bg = '#e99a90' },
              DiffChange = { bg = '#b8d4cf' },
              DiffText = { bg = '#79b7aa', bold = true },
            }
          or {
            DiffAdd = { bg = '#274f28' },
            DiffDelete = { bg = '#632b2b' },
            DiffChange = { bg = '#254e4a' },
            DiffText = { bg = '#2f7568', bold = true },
          }

        for group, highlight in pairs(highlights) do
          vim.api.nvim_set_hl(0, group, highlight)
        end
      end

      ---@diagnostic disable-next-line: missing-fields
      require('gruvbox').setup {
        styles = {
          comments = { italic = false }, -- Disable italics in comments
        },
      }

      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('gruvbox-diff-highlights', { clear = true }),
        pattern = 'gruvbox',
        callback = set_diff_highlights,
      })

      vim.cmd.colorscheme 'gruvbox'
      set_diff_highlights()
    end,
  },

  { -- Buffer tabs at the top
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',
    event = 'VimEnter',
    opts = {
      options = {
        diagnostics = 'nvim_lsp',
        close_command = function(bufnr)
          require('mini.bufremove').delete(bufnr, false)
        end,
        right_mouse_command = function(bufnr)
          require('mini.bufremove').delete(bufnr, false)
        end,
        offsets = {
          { filetype = 'neo-tree', text = 'File Explorer', separator = true, text_align = 'left' },
        },
      },
    },
  },

  { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      require('mini.ai').setup { n_lines = 500 }

      require('mini.surround').setup()

      require('mini.bufremove').setup()

      local starter = require 'mini.starter'
      starter.setup {
        items = { { name = '', action = '', section = '' } },
        footer = '',
        content_hooks = { starter.gen_hook.aligning('center', 'top') },
      }

      local statusline = require 'mini.statusline'
      statusline.setup { use_icons = vim.g.have_nerd_font }

      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end
    end,
  },
}
