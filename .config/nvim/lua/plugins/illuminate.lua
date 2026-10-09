return {
  {
    'RRethy/vim-illuminate',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = {
      delay = 200,
      filetypes_denylist = { 'NvimTree', 'neo-tree', 'lazy', 'mason', 'TelescopePrompt' },
    },
    config = function(_, opts)
      require('illuminate').configure(opts)
    end,
  },
}
