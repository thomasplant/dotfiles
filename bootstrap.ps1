#Requires -Version 7
<#
.SYNOPSIS
    Install the complete Windows toolchain; configuration linking is separate.
.DESCRIPTION
    Two layers:
      1. WinGet: git, mise, GCC/Make and 7-Zip. PSGallery: PowerShell modules.
      2. mise (https://mise.jdx.dev): the shared CLI toolchain listed in
         .config/mise/config.toml - neovim, ripgrep, fzf, lazygit, delta, fd,
         bat, zoxide, oh-my-posh, node, markdownlint-cli2 and Pi.
    Installs missing tools/modules without upgrading existing ones (use
    `mise upgrade` for that), and reconciles Neovim's local npm dependencies.
    No Chocolatey is required. Package installers may request elevation.
.EXAMPLE
    ./bootstrap.ps1 -WhatIf
.EXAMPLE
    ./bootstrap.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Use bootstrap.sh on macOS/Linux.' }

function Get-Executable([string]$Name) {
    $command = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($command) { return $command.Source }
}

function Invoke-CheckedCommand([string]$Command, [string[]]$Arguments) {
    $executable = Get-Executable $Command
    if (-not $executable) { throw "$Command is unavailable. Open a new terminal after installing it, then rerun." }
    & $executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE." }
}

function Update-ProcessPath {
    # Keep caller-specific PATH entries while picking up newly installed tools.
    $paths = @($env:Path, [Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User'))
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $env:Path = (@(foreach ($path in $paths) {
        foreach ($entry in ($path -split ';')) {
            if ($entry -and $seen.Add($entry)) { [Environment]::ExpandEnvironmentVariables($entry) }
        }
    })) -join ';'
}

function Add-UserPath {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Directory)
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { return }
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($current -split ';') -notcontains $Directory) {
        if (-not $PSCmdlet.ShouldProcess($Directory, 'Append to current-user PATH')) { return }
        $updated = (@($current, $Directory) | Where-Object { $_ }) -join ';'
        [Environment]::SetEnvironmentVariable('Path', $updated, 'User')
    }
    if (-not $WhatIfPreference) { Update-ProcessPath }
}

function Install-WinGetTool {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Package, [string[]]$Commands, [string]$ExtraPath)
    $missing = @($Commands | Where-Object { -not (Get-Executable $_) })
    if ($missing.Count -and $ExtraPath) {
        Add-UserPath $ExtraPath
        $missing = @($Commands | Where-Object { -not (Get-Executable $_) })
    }
    if (-not $missing.Count) { Write-Host "ok        $($Commands -join ', ')"; return }
    if ($PSCmdlet.ShouldProcess($Package, 'Install using WinGet')) {
        if (-not (Get-Executable 'winget')) {
            throw 'WinGet is required. Install/update App Installer from the Microsoft Store, then rerun.'
        }
        Invoke-CheckedCommand 'winget' @('install', '--id', $Package, '--exact',
            '--source', 'winget', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
        Update-ProcessPath
        if ($ExtraPath) { Add-UserPath $ExtraPath }
        $missing = @($Commands | Where-Object { -not (Get-Executable $_) })
        if ($missing.Count) {
            throw "Installed $Package, but $($missing -join ', ') is not on PATH. Open a new terminal, then rerun."
        }
    }
}

# Validate the checkout before any installation.
$config = Join-Path $PSScriptRoot '.config\nvim'
if (-not (Test-Path -LiteralPath (Join-Path $config 'package-lock.json'))) {
    throw "Missing Neovim dependency lockfile in $config."
}

$miseConfig = Join-Path $PSScriptRoot '.config\mise\config.toml'
if (-not (Test-Path -LiteralPath $miseConfig)) { throw "Missing mise config $miseConfig." }

# --- 1. System packages ------------------------------------------------------

Install-WinGetTool -Package 'Git.Git'   -Commands 'git'
Install-WinGetTool -Package 'jdx.mise'  -Commands 'mise'

# Telescope's Windows Makefile uses GCC. WinLibs provides both GCC and GNU Make
# (named mingw32-make); retain existing GCC + make installations if available.
if ((Get-Executable 'gcc') -and ((Get-Executable 'make') -or (Get-Executable 'mingw32-make'))) {
    Write-Host 'ok        GCC and Make'
} else {
    Install-WinGetTool -Package 'BrechtSanders.WinLibs.POSIX.UCRT' -Commands @('gcc', 'mingw32-make')
}
# Use maintained archive tooling rather than the obsolete GnuWin32 UnZip build.
$programFiles = if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }
$sevenZipDirectory = Join-Path $programFiles '7-Zip'
Install-WinGetTool -Package '7zip.7zip' -Commands '7z' -ExtraPath $sevenZipDirectory

foreach ($module in @('CompletionPredictor', 'posh-git', 'PSFzf')) {
    if (Get-Module -ListAvailable -Name $module) { Write-Host "ok        $module"; continue }
    if ($PSCmdlet.ShouldProcess($module, 'Install PowerShell module from PSGallery for current user')) {
        Install-Module -Name $module -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
    }
}

# --- 2. mise toolchain -------------------------------------------------------

# Shims are real .exe files, so GUI apps and other shells find the tools too.
# Windows puts the user PATH after the machine PATH, so the PowerShell profile
# also prepends the shims to win over older machine-wide installations.
$miseShims = Join-Path $env:LOCALAPPDATA 'mise\shims'
if ($PSCmdlet.ShouldProcess($miseShims, 'Create mise shims directory')) {
    New-Item -ItemType Directory -Path $miseShims -Force | Out-Null
}
Add-UserPath $miseShims
if (-not $WhatIfPreference) { $env:Path = "$miseShims;$env:Path" }

# install.ps1 links the config into ~/.config/mise later; read it from the repo
# now so this script can run first. The shims (npm, oh-my-posh) below also need
# it to pick a version, so keep it set until the mise-dependent steps are done.
$env:MISE_GLOBAL_CONFIG_FILE = $miseConfig
try {
    # Missing tools are installed, existing kept.
    if ($PSCmdlet.ShouldProcess($miseConfig, 'Install the mise toolchain')) {
        Invoke-CheckedCommand 'mise' @('install')
        Invoke-CheckedCommand 'mise' @('reshim')
    }

    if ($PSCmdlet.ShouldProcess($config, 'Run npm ci with mise node (includes Tree-sitter CLI installation scripts)')) {
        Invoke-CheckedCommand 'npm' @('ci', '--prefix', $config)
    }

    # Hack Nerd Font, via the mise-installed oh-my-posh. WSL uses this Windows font too.
    $hackFont = 'HackNerdFontMono-Regular.ttf'
    $fontInstalled = (Test-Path (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts\$hackFont")) -or
                     (Test-Path (Join-Path $env:WINDIR "Fonts\$hackFont"))
    if ($fontInstalled) { Write-Host 'ok        Hack Nerd Font' }
    elseif ($PSCmdlet.ShouldProcess('Hack Nerd Font', 'Install for current user using oh-my-posh')) {
        Invoke-CheckedCommand 'oh-my-posh' @('font', 'install', 'Hack', '--plain')
        Write-Host 'Set Windows Terminal''s font to "Hack Nerd Font Mono" if it is not already.'
    }
} finally {
    Remove-Item Env:MISE_GLOBAL_CONFIG_FILE -ErrorAction SilentlyContinue -WhatIf:$false
}

# Older installations (WinGet, Chocolatey, global npm) still work, but anything
# outside PowerShell may pick them up first. Report them so they can be removed.
if (-not $WhatIfPreference) {
    $shadowed = foreach ($name in @('nvim', 'rg', 'fzf', 'lazygit', 'delta', 'fd', 'bat',
            'zoxide', 'oh-my-posh', 'node', 'npm', 'markdownlint-cli2', 'pi')) {
        Get-Command -Name $name -CommandType Application -All -ErrorAction SilentlyContinue |
            Where-Object { (Split-Path $_.Source) -ne $miseShims } |
            ForEach-Object { "  $name`t$($_.Source)" }
    }
    if ($shadowed) {
        Write-Host ''
        Write-Host 'Other copies of mise-managed tools found (PowerShell uses mise; consider uninstalling):'
        $shadowed | Select-Object -Unique | ForEach-Object { Write-Host $_ }
    }
}

Write-Host ''
Write-Host 'Next: open a new PowerShell terminal, then ./install.ps1 -WhatIf and ./install.ps1.'
Write-Host 'Update tools later with: mise upgrade'
Write-Host 'Set RIPGREP_CONFIG_PATH to ~/.ripgreprc if it is not already configured.'
Write-Host 'Run :checkhealth dotfiles in Neovim. For an existing plugin setup, use :Lazy install then :Lazy build telescope-fzf-native.nvim.'
Write-Host 'Start Pi after linking; package reinstallations may require applying its Windows shell patch.'
