param(
    [string]$ApiKey
)

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $secure = Read-Host "请输入 API Key" -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $ApiKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

$SettingsDir = if ([string]::IsNullOrWhiteSpace($env:CLAUDE_CONFIG_DIR)) {
    Join-Path $HOME ".claude"
} else {
    $env:CLAUDE_CONFIG_DIR
}
$SettingsFile = Join-Path $SettingsDir "settings.json"

New-Item -ItemType Directory -Force -Path $SettingsDir | Out-Null

$data = @{}

if (Test-Path $SettingsFile) {
    $raw = Get-Content $SettingsFile -Raw -ErrorAction Stop
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        $parsed = $raw | ConvertFrom-Json -Depth 100

        $data = @{}
        foreach ($p in $parsed.PSObject.Properties) {
            $data[$p.Name] = $p.Value
        }
    }
}

if ($data.ContainsKey("env") -and $null -ne $data["env"]) {
    $envTable = @{}
    foreach ($p in $data["env"].PSObject.Properties) {
        $envTable[$p.Name] = $p.Value
    }
} else {
    $envTable = @{}
}

$envTable["ANTHROPIC_AUTH_TOKEN"] = $ApiKey
$envTable["ANTHROPIC_BASE_URL"] = "https://api.xi-xu.me"
$envTable["ANTHROPIC_DEFAULT_HAIKU_MODEL"] = "gpt-5.4"
$envTable["ANTHROPIC_DEFAULT_OPUS_MODEL"] = "gpt-5.4"
$envTable["ANTHROPIC_DEFAULT_SONNET_MODEL"] = "gpt-5.4"
$envTable["CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"] = "1"
$envTable["CLAUDE_CODE_SUBAGENT_MODEL"] = "gpt-5.4"

$data["env"] = $envTable

if (Test-Path $SettingsFile) {
    Copy-Item $SettingsFile "$SettingsFile.bak" -Force
}

$json = $data | ConvertTo-Json -Depth 100
Set-Content -Path $SettingsFile -Value $json -Encoding UTF8

Write-Host "已更新: $SettingsFile"
Write-Host "完成。"
Write-Host "你可以执行以下命令查看结果："
Write-Host "Get-Content $SettingsFile"
