-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    {
      '<leader>e',
      function()
        if vim.bo.filetype == 'neo-tree' then
          vim.cmd 'Neotree close'
          return
        end
        if vim.bo.filetype == 'ministarter' then
          -- follow_current_file otherwise implicitly reveals the starter's virtual URI.
          require('neo-tree.command').execute {
            action = 'focus',
            source = 'filesystem',
            reveal = false,
            dir = vim.fn.getcwd(),
          }
          return
        end
        vim.cmd 'Neotree reveal'
      end,
      desc = 'NeoTree toggle/reveal',
    },
    {
      '<leader>ge',
      '<cmd>Neotree git_status<CR>',
      desc = 'Open Git status explorer',
    },
  },
  opts = {
    -- Ignored-file discovery takes several seconds in this monorepo and those
    -- files are not displayed in the Git Status source.
    git_status_async = false,
    event_handlers = {
      {
        event = 'before_git_status',
        handler = function(args)
          for index, argument in ipairs(args.status_args) do
            if vim.startswith(argument, '--ignored=') then
              args.status_args[index] = '--ignored=no'
            end
          end
        end,
      },
    },
    filesystem = {
      commands = {
        clear_filter = function(state)
          local node = state.tree and state.tree:get_node()
          local path = node and node:get_id()
          local fs = require 'neo-tree.sources.filesystem'
          local renderer = require 'neo-tree.ui.renderer'

          -- Restore the unfiltered tree, but reveal the selection rather than
          -- returning to the folders that were open before the search.
          fs.reset_search(state, false)
          if node and node.type == 'directory' then
            state.force_open_folders = state.force_open_folders or {}
            table.insert(state.force_open_folders, path)
          end
          fs.navigate(state, nil, path, function()
            if path then
              renderer.focus_node(state, path, false)
            end
          end)
        end,
      },
      follow_current_file = {
        enabled = true,
        leave_dirs_open = false,
      },
      window = {
        mappings = {
          Z = 'expand_all_subnodes',
        },
      },
    },
    git_status = {
      commands = {
        open_diff = function(state)
          local node = state.tree:get_node()
          if node.type == 'file' then
            vim.cmd('DiffviewOpen -- ' .. vim.fn.fnameescape(node.path))
          else
            vim.cmd 'DiffviewOpen'
          end
        end,
      },
      window = {
        mappings = {
          D = 'open_diff',
        },
      },
    },
  },
}
