return {
  {
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewClose', 'DiffviewFileHistory', 'DiffviewOpen' },
    -- Diff hooks use ibl to hide indentation guides in diff buffers.
    dependencies = { 'nvim-lua/plenary.nvim', 'nvim-tree/nvim-web-devicons', 'lukas-reineke/indent-blankline.nvim' },
    keys = {
      { '<leader>gd', '<cmd>DiffviewOpen<CR>', desc = 'Open working tree diff' },
      { '<leader>gD', '<cmd>DiffviewOpen origin/HEAD...HEAD<CR>', desc = 'Diff branch against default branch' },
      { '<leader>gc', '<cmd>DiffviewClose<CR>', desc = 'Close diff view' },
      { '<leader>gf', '<cmd>DiffviewFileHistory %<CR>', desc = 'Current file history' },
      { '<leader>gF', '<cmd>DiffviewFileHistory<CR>', desc = 'Repository history' },
    },
    opts = function()
      local actions = require 'diffview.actions'
      local fold_descriptions = {
        za = 'Toggle fold',
        zA = 'Toggle fold recursively',
        ze = 'Scroll cursor to right edge',
        zE = 'Delete all folds',
        zo = 'Open fold',
        zc = 'Close fold',
        zO = 'Open fold recursively',
        zC = 'Close fold recursively',
        zr = 'Open one fold level',
        zm = 'Close one fold level',
        zR = 'Open all folds',
        zM = 'Close all folds',
        zv = 'Open folds around cursor',
        zx = 'Update folds around cursor',
        zX = 'Reapply folds',
        zn = 'Disable folding',
        zN = 'Enable folding',
        zi = 'Toggle folding',
      }

      for _, mapping in ipairs(actions.compat.fold_cmds) do
        mapping[4].desc = fold_descriptions[mapping[2]]
      end

      local diff_buffers = {}
      local diff_windows = {}
      local show_full_file = false

      local function apply_diff_folds(command)
        for winid in pairs(diff_windows) do
          if vim.api.nvim_win_is_valid(winid) then
            vim.api.nvim_win_call(winid, function()
              vim.cmd.normal { command, bang = true }
            end)
          else
            diff_windows[winid] = nil
          end
        end
      end

      local function toggle_all_diff_folds()
        show_full_file = not show_full_file
        apply_diff_folds(show_full_file and 'zR' or 'zM')
      end

      local function set_indent_guides(enabled)
        for bufnr in pairs(diff_buffers) do
          if vim.api.nvim_buf_is_valid(bufnr) then
            require('ibl').setup_buffer(bufnr, { enabled = enabled })
          end
        end
      end

      return {
        hooks = {
          diff_buf_read = function(bufnr)
            diff_buffers[bufnr] = true
            require('ibl').setup_buffer(bufnr, { enabled = false })
          end,
          diff_buf_win_enter = function(_, winid)
            diff_windows[winid] = true
            if show_full_file then
              vim.cmd.normal { 'zR', bang = true }
            end
          end,
          view_enter = function()
            set_indent_guides(false)
          end,
          view_leave = function()
            set_indent_guides(true)
          end,
          view_closed = function()
            set_indent_guides(true)
            diff_buffers = {}
            diff_windows = {}
            show_full_file = false
          end,
        },
        keymaps = {
          view = {
            { 'n', 'q', '<cmd>DiffviewClose<CR>', { desc = 'Close diff view' } },
            { 'n', '<leader>e', actions.toggle_files, { desc = 'Toggle file panel' } },
            { 'n', '<leader>ga', toggle_all_diff_folds, { desc = 'Toggle full file in diff' } },
            { 'n', '<leader>gl', actions.cycle_layout, { desc = 'Toggle diff layout' } },
          },
          file_panel = {
            { 'n', 'q', '<cmd>DiffviewClose<CR>', { desc = 'Close diff view' } },
            { 'n', '<leader>e', actions.toggle_files, { desc = 'Toggle file panel' } },
            { 'n', '<leader>ga', toggle_all_diff_folds, { desc = 'Toggle full file in diff' } },
            { 'n', '<leader>gl', actions.cycle_layout, { desc = 'Toggle diff layout' } },
          },
          file_history_panel = {
            { 'n', 'q', '<cmd>DiffviewClose<CR>', { desc = 'Close diff view' } },
          },
        },
      }
    end,
  },
}
