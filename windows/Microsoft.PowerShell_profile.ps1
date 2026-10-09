
Set-Alias lvim 'C:\Users\Thomas Plant\.local\bin\lvim.ps1'
$teamExplorerPath = 'C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer'
if ($teamExplorerPath -notin ($env:Path -split ';')) { $env:Path += ";$teamExplorerPath" }
Set-Alias oc opencode
Set-Alias lg lazygit

function gst { git status @args }

function lt { Get-ChildItem -Force @args | Sort-Object LastWriteTime }

# New Windows Terminal window in the current directory.
function nwt { wt -d $PWD.Path }

# Delivra module dev servers. The script resolves the repo root from its own location,
# so it has to stay at <repo>\tools - call it by absolute path instead of copying it out.
function start-module { & 'C:\Development\delivra\tools\start-module.ps1' @args }

# touch: create the file if missing, otherwise bump its timestamp (never truncates).
function touch {
    param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Path)
    foreach ($p in $Path) {
        if (Test-Path -LiteralPath $p) {
            (Get-Item -LiteralPath $p).LastWriteTime = Get-Date
        } else {
            New-Item -ItemType File -Path $p | Out-Null
        }
    }
}

# Prompt: follow Windows light/dark for the gruvbox palette.
# delta rides along: under lazygit its OSC-11 background query gets no answer (lazygit
# owns stdin), so it would always fall back to dark. Tell it explicitly instead — the
# light-mode/dark-mode features are defined in ~/.gitconfig.
function Set-ColorMode {
    param([ValidateSet('light', 'dark')][string]$Mode)
    $env:OMP_MODE = $Mode
    $env:DELTA_FEATURES = "+$Mode-mode"
}
function Sync-PromptMode {
    $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    $light = (Get-ItemProperty $k -Name AppsUseLightTheme -ErrorAction SilentlyContinue).AppsUseLightTheme
    Set-ColorMode ($light -eq 1 ? 'light' : 'dark')
}
Sync-PromptMode
function omp-light { Set-ColorMode light }
function omp-dark  { Set-ColorMode dark }

# --- Completion -------------------------------------------------------------

$nonInteractiveArguments = '-Command', '-CommandWithArgs', '-EncodedCommand', '-File', '-NonInteractive'
$isInteractiveSession = -not [Console]::IsInputRedirected -and
    -not [Console]::IsOutputRedirected -and
    -not ([Environment]::GetCommandLineArgs() | Where-Object { $_ -in $nonInteractiveArguments })

# PSReadLine: vi editing, menu completion, inline prediction from history+completers.
Import-Module PSReadLine
if ($isInteractiveSession) { Import-Module CompletionPredictor }

# EditMode resets the whole keymap, so it MUST come before any Set-PSReadLineKeyHandler
# below and before PSFzf registers its chords.
Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -ViModeIndicator Cursor   # blinking block = command mode, bar = insert

# Prediction needs a real console; skip it when output is redirected (scripts, CI).
if ($isInteractiveSession) {
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
}
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -MaximumHistoryCount 20000

# Insert mode: keep the completion/prediction ergonomics.
Set-PSReadLineKeyHandler -ViMode Insert -Key UpArrow         -Function HistorySearchBackward
Set-PSReadLineKeyHandler -ViMode Insert -Key DownArrow       -Function HistorySearchForward
Set-PSReadLineKeyHandler -ViMode Insert -Key RightArrow      -Function ForwardWord        # accept one word of the suggestion
Set-PSReadLineKeyHandler -ViMode Insert -Key Ctrl+RightArrow -Function AcceptSuggestion
Set-PSReadLineKeyHandler -ViMode Insert -Key F2              -Function SwitchPredictionView

# Drive the ListView prediction dropdown from the home row — no reaching for arrows.
# n/p walk the list, Ctrl+f takes the whole entry, Alt+f takes one word at a time.
Set-PSReadLineKeyHandler -ViMode Insert -Key Ctrl+n -Function NextSuggestion
Set-PSReadLineKeyHandler -ViMode Insert -Key Ctrl+p -Function PreviousSuggestion
Set-PSReadLineKeyHandler -ViMode Insert -Key Ctrl+f -Function AcceptSuggestion
Set-PSReadLineKeyHandler -ViMode Insert -Key Alt+f  -Function AcceptNextSuggestionWord

# Command mode: k/j walk history by prefix, like ↑/↓ do in insert mode.
Set-PSReadLineKeyHandler -ViMode Command -Key UpArrow        -Function HistorySearchBackward
Set-PSReadLineKeyHandler -ViMode Command -Key DownArrow      -Function HistorySearchForward
Set-PSReadLineKeyHandler -ViMode Command -Key k              -Function HistorySearchBackward
Set-PSReadLineKeyHandler -ViMode Command -Key j              -Function HistorySearchForward
Set-PSReadLineKeyHandler -ViMode Command -Key F2             -Function SwitchPredictionView
Set-PSReadLineKeyHandler -ViMode Command -Key Ctrl+n         -Function NextSuggestion
Set-PSReadLineKeyHandler -ViMode Command -Key Ctrl+p         -Function PreviousSuggestion

# `v` in command mode opens the line in a real editor; write, quit, and it runs.
# Must be a launchable executable — lvim is only a .ps1 shim, so use nvim.exe.
if (-not $env:EDITOR) { $env:EDITOR = 'nvim' }

# `kj` leaves insert mode. NOT a PSReadLine chord: binding 'k,j' as a chord makes
# PSReadLine wait indefinitely for the second key and swallow a lone 'k', which
# breaks typing words like "hunk". Instead, peek for a following 'j' within a short
# window (vim's timeoutlen) and insert a normal 'k' if it does not arrive.
Set-PSReadLineKeyHandler -ViMode Insert -Key 'k' -ScriptBlock {
    $deadline = [datetime]::UtcNow.AddMilliseconds(200)
    while (-not [Console]::KeyAvailable -and [datetime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 5
    }

    if (-not [Console]::KeyAvailable) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('k')
        return
    }

    $next = [Console]::ReadKey($true)
    if ($next.KeyChar -eq 'j') {
        [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
        return
    }

    # Not the escape sequence: emit the 'k', then honour whatever the second key was.
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert('k')
    switch ($next.Key) {
        'Enter'     { [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine() }
        'Backspace' { [Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar() }
        'Tab'       { Initialize-Completion; [Microsoft.PowerShell.PSConsoleReadLine]::MenuComplete($null, $null) }
        'Escape'    { [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode() }
        'LeftArrow' { [Microsoft.PowerShell.PSConsoleReadLine]::BackwardChar() }
        'RightArrow'{ [Microsoft.PowerShell.PSConsoleReadLine]::ForwardChar() }
        'UpArrow'   { [Microsoft.PowerShell.PSConsoleReadLine]::HistorySearchBackward() }
        'DownArrow' { [Microsoft.PowerShell.PSConsoleReadLine]::HistorySearchForward() }
        default     {
            if (-not [char]::IsControl($next.KeyChar)) {
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert($next.KeyChar)
            }
        }
    }
}

# posh-git (368ms) and PSFzf (175ms) are the two slowest imports. Initialize them
# during the first idle period, while retaining first-use loading as a fallback.
function Initialize-Completion {
    if ($global:__completionReady) { return }

    # posh-git: git subcommands, flags, branches/remotes/tags, and for
    # `git add`/`checkout`/`restore`, the changed files from git status.
    Import-Module posh-git -Global

    # PSFzf: fuzzy pickers over files, history, git objects (fzf is on PATH).
    Import-Module PSFzf -Global
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    Set-PsFzfOption -EnableAliasFuzzyGitStatus -EnableAliasFuzzySetLocation
    Set-PsFzfOption -TabExpansion   # `git add **<Tab>` opens a multi-select fzf picker

    $global:__completionReady = $true
}

# Trigger keys: load on demand, then perform the action that was asked for.
foreach ($vi in 'Insert', 'Command') {
    Set-PSReadLineKeyHandler -ViMode $vi -Key Tab -ScriptBlock {
        Initialize-Completion
        [Microsoft.PowerShell.PSConsoleReadLine]::MenuComplete($null, $null)
    }
}
Set-PSReadLineKeyHandler -Key Ctrl+t -ScriptBlock { Initialize-Completion; Invoke-FzfPsReadlineHandlerProvider }
Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock { Initialize-Completion; Invoke-FzfPsReadlineHandlerHistory }
Set-PSReadLineKeyHandler -Key Alt+c  -ScriptBlock { Initialize-Completion; Invoke-FzfPsReadlineHandlerSetLocation }
Set-PSReadLineKeyHandler -Key Alt+a  -ScriptBlock { Initialize-Completion; Invoke-FzfPsReadlineHandlerHistoryArgs }

# The fgs / fd aliases live in PSFzf, so they need it loaded first.
function fgs { Initialize-Completion; Invoke-FuzzyGitStatus @args }
function fd  { Initialize-Completion; Invoke-FuzzySetLocation @args }

# Let the first prompt render before warming completion in this session's runspace.
# Registering OnIdle for command/file or redirected shells can keep PowerShell alive
# after its work completes, so limit warm-up to normal interactive sessions.
if ($isInteractiveSession) {
    Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
        Initialize-Completion
    } | Out-Null
}

# dotnet CLI completion.
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition "$commandAst" | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

# -----------------------------------------------------------------------------

# `oh-my-posh init` costs ~350ms, almost all of it spawning the exe just to print a
# one-line shim that dot-sources oh-my-posh's own hashed init script. Cache that line.
# The shim carries a per-session GUID, so swap in a fresh one on every launch.
function Initialize-Prompt {
    $config = Join-Path $HOME '.config\oh-my-posh\gruvbox-lean.omp.json'
    $shim   = Join-Path $HOME '.config\oh-my-posh\init-shim.ps1'

    $line = if (Test-Path $shim) { (Get-Content $shim -Raw).Trim() } else { $null }

    # Stale if: no cache, config edited since, or the hashed init it points at is
    # gone (which is what happens after an oh-my-posh upgrade).
    $stale = -not $line
    # $config is a symlink into ~/dotfiles; compare the target's timestamp, not the link's.
    $configItem = Get-Item $config
    if ($configItem.LinkTarget) { $configItem = Get-Item $configItem.ResolvedTarget }
    if (-not $stale) { $stale = $configItem.LastWriteTimeUtc -gt (Get-Item $shim).LastWriteTimeUtc }
    if (-not $stale) { $stale = -not ($line -match "&\s*'([^']+\.ps1)'" -and (Test-Path $Matches[1])) }

    if ($stale) {
        $line = (oh-my-posh init pwsh --config $config | Out-String).Trim()
        $line | Set-Content $shim -Encoding utf8
    }

    ($line -replace '(?<=POSH_SESSION_ID = ")[0-9a-fA-F-]{36}', [guid]::NewGuid().ToString()) |
        Invoke-Expression
}
Initialize-Prompt
