# Configure Claude Code for Xi Xu's AI Inference on Windows.
$ErrorActionPreference = 'Stop'

$defaultModel = 'gpt-5.5'
$timestamp = Get-Date -Format 'yyyyMMddHHmmss'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Backup-File([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        Copy-Item -LiteralPath $Path -Destination "$Path.bak.$script:timestamp" -Force
    }
}

$SettingsDir = if ([string]::IsNullOrWhiteSpace($env:CLAUDE_CONFIG_DIR)) { Join-Path $HOME ".claude" } else { $env:CLAUDE_CONFIG_DIR }
$claudeDir = $SettingsDir
$keyFile = Join-Path $claudeDir 'xixu.key'
$modelFile = Join-Path $claudeDir 'xixu.model'
New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
Backup-File $keyFile
Backup-File $modelFile

$secureKey = Read-Host 'Enter your Xi Xu API key' -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
try {
    $apiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw 'API key is required.'
}
Write-Utf8NoBom $keyFile $apiKey
Write-Utf8NoBom $modelFile $defaultModel
$apiKey = $null

if ($env:OS -eq 'Windows_NT') {
    try {
        $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        & icacls.exe $keyFile '/inheritance:r' '/grant:r' "*$sid`:(R,W)" | Out-Null
        & icacls.exe $modelFile '/inheritance:r' '/grant:r' "*$sid`:(R,W)" | Out-Null
    } catch {
        Write-Warning "Could not restrict the credential ACL automatically: $($_.Exception.Message)"
    }
}

$profileFile = $PROFILE
$profileDir = Split-Path -Parent $profileFile
New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
if (-not (Test-Path -LiteralPath $profileFile)) { Write-Utf8NoBom $profileFile '' }
Backup-File $profileFile

$start = "# >>> Xi Xu's AI Inference Claude Code >>>"
$end = "# <<< Xi Xu's AI Inference Claude Code <<<"
$profileText = [System.IO.File]::ReadAllText($profileFile)
$pattern = "(?ms)^$([regex]::Escape($start))\r?\n.*?^$([regex]::Escape($end))\r?\n?"
$profileText = [regex]::Replace($profileText, $pattern, '').TrimEnd()
$profileBlock = @'
# >>> Xi Xu's AI Inference Claude Code >>>
Remove-Item Function:\claude -ErrorAction SilentlyContinue
$script:XiXuClaudeCommand = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1

function global:claude {
    Write-Host "`nXi Xu's AI Inference"
    Write-Host '----------------------'
    if (-not $script:XiXuClaudeCommand) {
        Write-Error 'Claude Code not found. Install Claude Code first, then restart PowerShell.'
        return
    }
    $claudeConfigDir = if ([string]::IsNullOrWhiteSpace($env:CLAUDE_CONFIG_DIR)) { Join-Path $HOME ".claude" } else { $env:CLAUDE_CONFIG_DIR }
    $keyPath = Join-Path $claudeConfigDir 'xixu.key'
    $modelPath = Join-Path $claudeConfigDir 'xixu.model'
    if (-not (Test-Path -LiteralPath $keyPath) -or -not (Test-Path -LiteralPath $modelPath)) {
        Write-Error 'Missing Xi Xu Claude Code configuration. Run the setup script again.'
        return
    }
    $key = [System.IO.File]::ReadAllText($keyPath).Trim()
    $model = [System.IO.File]::ReadAllText($modelPath).Trim()
    $names = @(
        'ANTHROPIC_BASE_URL', 'ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_API_KEY',
        'ANTHROPIC_MODEL', 'ANTHROPIC_DEFAULT_OPUS_MODEL', 'ANTHROPIC_DEFAULT_SONNET_MODEL',
        'ANTHROPIC_DEFAULT_HAIKU_MODEL', 'ANTHROPIC_DEFAULT_FABLE_MODEL',
        'CLAUDE_CODE_SUBAGENT_MODEL', 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
        'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_FOUNDRY'
    )
    $old = @{}
    foreach ($name in $names) {
        $old[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    try {
        $env:ANTHROPIC_BASE_URL = 'https://api.xi-xu.me'
        $env:ANTHROPIC_AUTH_TOKEN = $key
        Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
        $env:ANTHROPIC_MODEL = $model
        $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $model
        $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $model
        $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $model
        $env:ANTHROPIC_DEFAULT_FABLE_MODEL = $model
        $env:CLAUDE_CODE_SUBAGENT_MODEL = $model
        $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1'
        Remove-Item Env:CLAUDE_CODE_USE_BEDROCK, Env:CLAUDE_CODE_USE_VERTEX, Env:CLAUDE_CODE_USE_FOUNDRY -ErrorAction SilentlyContinue
        & $script:XiXuClaudeCommand.Source @args
    } finally {
        foreach ($name in $names) {
            [Environment]::SetEnvironmentVariable($name, $old[$name], 'Process')
        }
        $key = $null
    }
}
# <<< Xi Xu's AI Inference Claude Code <<<
'@
$newProfile = if ($profileText) { "$profileText`r`n`r`n$profileBlock`r`n" } else { "$profileBlock`r`n" }
Write-Utf8NoBom $profileFile $newProfile

Write-Host "`nDone."
Write-Host "Credentials: $keyFile (restricted ACL requested)"
Write-Host "Model: $modelFile"
Write-Host "Profile: $profileFile"
Write-Host 'Restart PowerShell, or run: . $PROFILE'
Write-Host 'Then run: claude'
