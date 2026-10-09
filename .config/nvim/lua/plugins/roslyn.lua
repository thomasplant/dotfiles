-- Keep early setup: project selection and Windows command must precede LSP startup.
return {
  { -- C# LSP (Microsoft's Roslyn-based — replaces omnisharp)
    'seblyng/roslyn.nvim',
    ft = { 'cs', 'csproj', 'sln', 'slnx', 'props', 'targets' },
    opts = {},
    init = function()
      require('roslyn').setup {
        ignore_target = function()
          return true
        end,
      }

      if vim.fn.has 'win32' == 1 then
        vim.lsp.config('roslyn', {
          cmd = {
            'dotnet',
            vim.fs.joinpath(vim.fn.stdpath 'data', 'mason', 'packages', 'roslyn', 'libexec', 'Microsoft.CodeAnalysis.LanguageServer.dll'),
            '--logLevel=Information',
            '--extensionLogDirectory=' .. vim.fs.dirname(vim.lsp.log.get_filename()),
            '--stdio',
          },
        })
      end
    end,
  },
}
