#Requires -Version 7
<#
.SYNOPSIS
    Install the complete Windows toolchain; configuration linking is separate.
.DESCRIPTION
    Uses WinGet, PSGallery and npm. Installs missing tools/modules without
    upgrading existing ones, and reconciles Neovim's local npm dependencies.
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

foreach ($tool in @(
    @{ Command = 'git';         Package = 'Git.Git' },
    @{ Command = 'nvim';        Package = 'Neovim.Neovim' },
    @{ Command = 'rg';          Package = 'BurntSushi.ripgrep.MSVC' },
    @{ Command = 'fzf';         Package = 'junegunn.fzf' },
    @{ Command = 'lazygit';     Package = 'JesseDuffield.lazygit' },
    @{ Command = 'delta';       Package = 'dandavison.delta' },
    @{ Command = 'fd';          Package = 'sharkdp.fd' },
    @{ Command = 'bat';         Package = 'sharkdp.bat' },
    @{ Command = 'node';        Package = 'OpenJS.NodeJS.LTS' },
    @{ Command = 'oh-my-posh';  Package = 'JanDeDobbeleer.OhMyPosh' }
)) {
    Install-WinGetTool -Package $tool.Package -Commands $tool.Command
}

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

if (-not $WhatIfPreference) {
    $version = & (Get-Executable 'nvim') --version | Select-Object -First 1
    if ($version -notmatch '^NVIM v(\d+)\.(\d+)' -or
        ([int]$Matches[1] -eq 0 -and [int]$Matches[2] -lt 12)) {
        throw "Neovim 0.12+ is required; found '$version'. Upgrade it, then rerun."
    }
    $version = & (Get-Executable 'node') --version
    if ([version]($version.TrimStart('v')) -lt [version]'22.19.0') {
        throw "Node.js 22.19+ is required for Pi; found '$version'. Upgrade it, then rerun."
    }
}

foreach ($module in @('CompletionPredictor', 'posh-git', 'PSFzf')) {
    if (Get-Module -ListAvailable -Name $module) { Write-Host "ok        $module"; continue }
    if ($PSCmdlet.ShouldProcess($module, 'Install PowerShell module from PSGallery for current user')) {
        Install-Module -Name $module -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
    }
}

if ($PSCmdlet.ShouldProcess($config, 'Run npm ci (includes Tree-sitter CLI installation scripts)')) {
    Invoke-CheckedCommand 'npm' @('ci', '--prefix', $config)
}
if (Get-Executable 'markdownlint') { Write-Host 'ok        markdownlint' }
elseif ($PSCmdlet.ShouldProcess('markdownlint-cli', 'Install global npm package for Markdown linting')) {
    Invoke-CheckedCommand 'npm' @('install', '--global', 'markdownlint-cli')
    Update-ProcessPath
}

if (Get-Executable 'pi') { Write-Host 'ok        pi' }
elseif ($PSCmdlet.ShouldProcess('@earendil-works/pi-coding-agent', 'Install Pi globally using npm')) {
    Invoke-CheckedCommand 'npm' @('install', '--global', '--ignore-scripts', '@earendil-works/pi-coding-agent')
    Update-ProcessPath
}

Write-Host ''
Write-Host 'Next: open a new PowerShell terminal, then ./install.ps1 -WhatIf and ./install.ps1.'
Write-Host 'Set RIPGREP_CONFIG_PATH to ~/.ripgreprc if it is not already configured.'
Write-Host 'Run :checkhealth dotfiles in Neovim. For an existing plugin setup, use :Lazy install then :Lazy build telescope-fzf-native.nvim.'
Write-Host 'Start Pi after linking; package reinstallations may require applying its Windows shell patch.'
