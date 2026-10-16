# Configure Codex CLI for Xi Xu's AI Inference on Windows.
$ErrorActionPreference = 'Stop'

$brand = "Xi Xu's AI Inference"
$providerId = 'xixu'
$baseUrl = 'https://api.xi-xu.me/v1'
$modelCatalogUrl = 'https://api.xi-xu.me/v1/models'
$envKey = 'XIXU_API_KEY'
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

$codexDir = Join-Path $HOME '.codex'
$configFile = Join-Path $codexDir 'config.toml'
$keyFile = Join-Path $codexDir 'xixu.key'
New-Item -ItemType Directory -Path $codexDir -Force | Out-Null

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
$apiKey = $null

if ($env:OS -eq 'Windows_NT') {
    try {
        $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        & icacls.exe $keyFile '/inheritance:r' '/grant:r' "*$sid`:(R,W)" | Out-Null
    } catch {
        Write-Warning "Could not restrict the key file ACL automatically: $($_.Exception.Message)"
    }
}

Backup-File $configFile
$sourceLines = if (Test-Path -LiteralPath $configFile) {
    [System.IO.File]::ReadAllLines($configFile)
} else {
    @()
}

$kept = New-Object 'System.Collections.Generic.List[string]'
$skipProvider = $false
$inTable = $false
foreach ($line in $sourceLines) {
    if ($line -match '^\s*\[model_providers\.xixu\]\s*$') {
        $skipProvider = $true
        continue
    }
    if ($line -match '^\s*\[') {
        $skipProvider = $false
        $inTable = $true
    }
    if ($skipProvider) { continue }
    if (-not $inTable -and $line -match '^\s*(model_provider|model|model_reasoning_effort|service_tier|approval_policy|approvals_reviewer)\s*=') {
        continue
    }
    $kept.Add($line)
}

$firstTable = -1
for ($i = 0; $i -lt $kept.Count; $i++) {
    if ($kept[$i] -match '^\s*\[') {
        $firstTable = $i
        break
    }
}
if ($firstTable -ge 0) {
    $topText = (($kept.GetRange(0, $firstTable).ToArray() -join "`n").Trim())
    $restText = (($kept.GetRange($firstTable, $kept.Count - $firstTable).ToArray() -join "`n").Trim())
} else {
    $topText = (($kept.ToArray() -join "`n").Trim())
    $restText = ''
}

$configText = @"
model_provider = "$providerId"
model = "$defaultModel"
model_reasoning_effort = "xhigh"
service_tier = "fast"
approvals_reviewer = "user"
"@.Trim()
if ($topText) { $configText += "`n`n$topText" }
$configText += @"


[model_providers.$providerId]
name = "$brand"
base_url = "$baseUrl"
model_catalog_url = "$modelCatalogUrl"
env_key = "$envKey"
wire_api = "responses"
disable_response_storage = true
"@
if ($restText) { $configText += "`n$restText`n" }
# Ensure Codex model discovery is enabled without duplicate feature keys.
$configLines = $configText -split [Environment]::NewLine | Where-Object { $_ -notlike '*api_key_model_discovery*' }
$configText = $configLines -join [Environment]::NewLine
if ($configText.Contains('[features]')) {
    $configText = $configText.Replace('[features]', '[features]' + [Environment]::NewLine + 'api_key_model_discovery = true')
} else {
    $configText = $configText.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + '[features]' + [Environment]::NewLine + 'api_key_model_discovery = true' + [Environment]::NewLine
}
Write-Utf8NoBom $configFile $configText

$profileFile = $PROFILE
$profileDir = Split-Path -Parent $profileFile
New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
if (-not (Test-Path -LiteralPath $profileFile)) { Write-Utf8NoBom $profileFile '' }
Backup-File $profileFile

$start = "# >>> Xi Xu's AI Inference Codex >>>"
$end = "# <<< Xi Xu's AI Inference Codex <<<"
$profileText = [System.IO.File]::ReadAllText($profileFile)
$pattern = "(?ms)^$([regex]::Escape($start))\r?\n.*?^$([regex]::Escape($end))\r?\n?"
$profileText = [regex]::Replace($profileText, $pattern, '').TrimEnd()
$profileBlock = @'
# >>> Xi Xu's AI Inference Codex >>>
Remove-Item Function:\codex -ErrorAction SilentlyContinue
$script:XiXuCodexCommand = Get-Command codex -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1

function global:codex {
    Write-Host "`nXi Xu's AI Inference"
    Write-Host '----------------------'
    if (-not $script:XiXuCodexCommand) {
        Write-Error 'Codex CLI not found. Install Codex CLI first, then restart PowerShell.'
        return
    }
    $keyPath = Join-Path $HOME '.codex\xixu.key'
    if (-not (Test-Path -LiteralPath $keyPath)) {
        Write-Error "Missing $keyPath. Run the setup script again."
        return
    }
    $key = [System.IO.File]::ReadAllText($keyPath).Trim()
    $hadKey = Test-Path Env:XIXU_API_KEY
    $oldKey = $env:XIXU_API_KEY
    try {
        $env:XIXU_API_KEY = $key
        & $script:XiXuCodexCommand.Source @args
    } finally {
        if ($hadKey) { $env:XIXU_API_KEY = $oldKey } else { Remove-Item Env:XIXU_API_KEY -ErrorAction SilentlyContinue }
        $key = $null
    }
}
# <<< Xi Xu's AI Inference Codex <<<
'@
$newProfile = if ($profileText) { "$profileText`r`n`r`n$profileBlock`r`n" } else { "$profileBlock`r`n" }
Write-Utf8NoBom $profileFile $newProfile

Write-Host "`nDone."
Write-Host "Config: $configFile"
Write-Host "Credentials: $keyFile (restricted ACL requested)"
Write-Host "Profile: $profileFile"
Write-Host 'Restart PowerShell, or run: . $PROFILE'
Write-Host 'Then run: codex'
