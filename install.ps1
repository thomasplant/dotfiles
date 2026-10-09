#Requires -Version 7
<#
.SYNOPSIS
    Windows counterpart of install.sh: symlink this repo's files into place.
.DESCRIPTION
    Existing real files/directories are moved aside to <name>.bak-<timestamp>, never deleted.
    Links that already point at the right file are left alone.
    Creating symlinks needs Developer Mode or an elevated shell.
.EXAMPLE
    ./install.ps1 -WhatIf     # preview
    ./install.ps1             # link
    ./install.ps1 -Undo       # remove links that point into this repo
#>
[CmdletBinding(SupportsShouldProcess)]
param([switch]$Undo)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot

# Repo file or directory (relative)       -> destination
$links = [ordered]@{
    '.config\git\config'                     = Join-Path $HOME '.config\git\config'
    '.config\ripgrep\ripgreprc'              = Join-Path $HOME '.ripgreprc'   # RIPGREP_CONFIG_PATH already points here
    '.config\lazygit\config.yml'             = Join-Path $env:LOCALAPPDATA 'lazygit\config.yml'
    '.config\nvim'                           = Join-Path $env:LOCALAPPDATA 'nvim'
    '.pi\agent'                              = Join-Path $HOME '.pi\agent'
    '.config\oh-my-posh\gruvbox-lean.omp.json' = Join-Path $HOME '.config\oh-my-posh\gruvbox-lean.omp.json'
    'windows\Microsoft.PowerShell_profile.ps1' = $PROFILE.CurrentUserCurrentHost
}

foreach ($entry in $links.GetEnumerator()) {
    $source = Join-Path $repo $entry.Key
    $dest   = $entry.Value
    $item   = Get-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
    $isOurs = $item -and $item.LinkTarget -and
              ([IO.Path]::GetFullPath($item.ResolvedTarget) -eq [IO.Path]::GetFullPath($source))

    if ($Undo) {
        if ($isOurs -and $PSCmdlet.ShouldProcess($dest, 'Remove symlink')) {
            Remove-Item -LiteralPath $dest
            Write-Host "unlinked  $dest"
        }
        continue
    }

    if ($isOurs) { Write-Host "ok        $dest"; continue }

    if ($item) {
        $backup = "$dest.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
        if ($PSCmdlet.ShouldProcess($dest, "Move existing file/directory to $backup")) {
            Move-Item -LiteralPath $dest -Destination $backup
            Write-Host "backed up $dest -> $backup"
        }
    }

    if ($PSCmdlet.ShouldProcess($dest, "Symlink to $source")) {
        New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
        try {
            New-Item -ItemType SymbolicLink -Path $dest -Target $source | Out-Null
        } catch {
            throw "Could not create symlink $dest. Enable Developer Mode (Settings > System > For developers) or run elevated. $_"
        }
        Write-Host "linked    $dest"
    }
}

if (-not $Undo) {
    Write-Host 'Pi config is included at .pi\agent. Restart Pi after installation; close Pi before migrating.'
    Write-Host ''
    Write-Host 'Machine-specific git settings (e.g. core.sshCommand) stay in ~/.gitconfig;'
    Write-Host 'git reads it after ~/.config/git/config, so they still apply.'
}
