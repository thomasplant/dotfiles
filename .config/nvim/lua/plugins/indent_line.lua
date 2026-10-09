return {
  { -- Add indentation guides even on blank lines
    'lukas-reineke/indent-blankline.nvim',
    -- Enable `lukas-reineke/indent-blankline.nvim`
    -- See `:help ibl`
    main = 'ibl',
    config = function()
      -- Define visible colors for the guides. Gruvbox's default Whitespace
      -- color is nearly invisible, so we override with brighter grays.
      -- Re-applied on every colorscheme change so it survives reloads.
      local function set_hl()
        vim.api.nvim_set_hl(0, 'IblIndent', { fg = '#665c54' }) -- normal guides (gruvbox bg3, clearly visible)
        vim.api.nvim_set_hl(0, 'IblScope', { fg = '#fe8019' }) -- current block (gruvbox orange, unmistakable)
      end
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('indent-guide-highlights', { clear = true }),
        callback = set_hl,
      })
      set_hl()

      -- NOTE: in ibl v3 `highlight` must be a LIST of group names, not a string.
      require('ibl').setup {
        indent = {
          char = '│',
          highlight = { 'IblIndent' },
        },
        scope = {
          enabled = true,
          highlight = { 'IblScope' },
          show_start = false,
          show_end = false,
        },
      }
    end,
  },
}
