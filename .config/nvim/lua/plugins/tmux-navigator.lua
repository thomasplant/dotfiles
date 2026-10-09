return {
  { -- Ctrl+h/j/k/l moves between nvim splits and tmux panes alike.
    -- The tmux half lives in ~/.config/tmux/tmux.conf. Outside tmux these
    -- behave like the plain <C-w>h/j/k/l window moves.
    'christoomey/vim-tmux-navigator',
    cmd = { 'TmuxNavigateLeft', 'TmuxNavigateDown', 'TmuxNavigateUp', 'TmuxNavigateRight' },
    init = function()
      -- Leaving nvim for another tmux pane keeps the window zoomed (tmux select-pane -Z),
      -- matching the -Z on the tmux.conf bindings.
      vim.g.tmux_navigator_preserve_zoom = 1
    end,
    keys = {
      { '<C-h>', '<cmd>TmuxNavigateLeft<CR>', desc = 'Move focus left (nvim/tmux)' },
      { '<C-j>', '<cmd>TmuxNavigateDown<CR>', desc = 'Move focus down (nvim/tmux)' },
      { '<C-k>', '<cmd>TmuxNavigateUp<CR>', desc = 'Move focus up (nvim/tmux)' },
      { '<C-l>', '<cmd>TmuxNavigateRight<CR>', desc = 'Move focus right (nvim/tmux)' },
    },
  },
}
