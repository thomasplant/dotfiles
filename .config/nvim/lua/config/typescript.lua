-- Use only the project's native TS7 binary; older/global tsc may not support LSP.
local M = {}

function M.setup(capabilities)
  local function tsc_cmd(root_dir)
    if root_dir then
      local exe_name = vim.fn.has 'win32' == 1 and 'tsc.exe' or 'tsc'
      local matches = vim.fn.glob(vim.fs.joinpath(root_dir, 'node_modules', '@typescript', 'typescript-*', 'lib', exe_name), true, true)
      for _, executable in ipairs(matches) do
        if vim.fn.executable(executable) == 1 then
          return executable
        end
      end
    end
    return nil
  end

  vim.lsp.config('tsc', {
    cmd = function(dispatchers, config)
      local exe = tsc_cmd(config.root_dir)
      if not exe then
        error(
          'TypeScript LSP: no project-local native tsc executable found under '
            .. (config.root_dir or '<unknown project>')
            .. '. Install TypeScript 7 RC or newer in the project and install its platform dependencies. '
            .. 'Older JavaScript-based TypeScript does not support --lsp.',
          0
        )
      end
      return vim.lsp.rpc.start({ exe, '--lsp', '--stdio' }, dispatchers)
    end,
    filetypes = {
      'javascript',
      'javascriptreact',
      'typescript',
      'typescriptreact',
    },
    capabilities = capabilities,
    -- Prefer TS project roots over the enclosing monorepo root; skip diff buffers.
    root_dir = function(bufnr, on_dir)
      if vim.startswith(vim.api.nvim_buf_get_name(bufnr), 'diffview://') then
        return
      end
      local root = vim.fs.root(bufnr, { 'tsconfig.json', 'jsconfig.json', 'package.json' })
      if root then
        on_dir(root)
      end
    end,
  })
  vim.lsp.enable 'tsc'
end

return M
