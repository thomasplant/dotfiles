-- Configuration prerequisites, available via :checkhealth dotfiles.

local check_version = function()
  local verstr = tostring(vim.version())
  if vim.fn.has 'nvim-0.12' == 1 then
    vim.health.ok(string.format("Neovim version is: '%s'", verstr))
  else
    vim.health.error(string.format("Neovim out of date: '%s'. This config requires Neovim 0.12 or newer", verstr))
  end
end

local check_external_reqs = function()
  -- Basic utilities; Windows WinLibs provides Make as mingw32-make.
  local make = vim.fn.has 'win32' == 1 and vim.fn.executable 'mingw32-make' == 1 and 'mingw32-make' or 'make'
  local tools = { 'git', make, 'rg' }
  if vim.fn.has 'win32' == 1 then
    tools[#tools + 1] = 'gcc'
    tools[#tools + 1] = '7z'
  else
    tools[#tools + 1] = 'unzip'
  end
  for _, exe in ipairs(tools) do
    local is_executable = vim.fn.executable(exe) == 1
    if is_executable then
      vim.health.ok(string.format("Found executable: '%s'", exe))
    else
      vim.health.warn(string.format("Could not find executable: '%s'", exe))
    end
  end

  return true
end

return {
  check = function()
    vim.health.start 'dotfiles'

    vim.health.info [[NOTE: Not every warning is a 'must-fix' in `:checkhealth`

  Fix only warnings for plugins and languages you intend to use.
    Mason will give warnings for languages that are not installed.
    You do not need to install, unless you want to use those languages!]]

    local uv = vim.uv or vim.loop
    vim.health.info('System Information: ' .. vim.inspect(uv.os_uname()))

    check_version()
    check_external_reqs()
  end,
}
