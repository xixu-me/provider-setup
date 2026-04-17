param(
    [string]$ApiKey
)

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $secure = Read-Host "请输入 XIXU_API_KEY" -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $ApiKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

$ConfigDir = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
    Join-Path $HOME ".codex"
} else {
    $env:CODEX_HOME
}
$ConfigFile = Join-Path $ConfigDir "config.toml"

New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
if (-not (Test-Path $ConfigFile)) {
    New-Item -ItemType File -Force -Path $ConfigFile | Out-Null
}

$content = Get-Content $ConfigFile -Raw -ErrorAction SilentlyContinue
if ($null -eq $content) {
    $content = ""
}

if ($content -match '(?m)^[ \t]*model_provider[ \t]*=') {
    $content = [regex]::Replace(
        $content,
        '(?m)^[ \t]*model_provider[ \t]*=.*$',
        'model_provider = "xixu"'
    )
} else {
    if ($content.Length -gt 0 -and -not $content.EndsWith("`n")) {
        $content += "`r`n"
    }
    $content += 'model_provider = "xixu"' + "`r`n"
}

$content = [regex]::Replace(
    $content,
    '(?ms)^\[model_providers\.xixu\]\s*.*?(?=^\[|\z)',
    ''
)

$xixuBlock = @'

[model_providers.xixu]
name = "Xi Xu''s AI Inference"
base_url = "https://api.xi-xu.me/v1"
env_key = "XIXU_API_KEY"
'@

$content = $content.TrimEnd() + "`r`n" + $xixuBlock + "`r`n"

Set-Content -Path $ConfigFile -Value $content -Encoding UTF8

$env:XIXU_API_KEY = $ApiKey
[System.Environment]::SetEnvironmentVariable("XIXU_API_KEY", $ApiKey, "User")

Write-Host "已完成："
Write-Host "1. 更新 $ConfigFile"
Write-Host "2. 设置当前会话环境变量 XIXU_API_KEY"
Write-Host "3. 持久化为用户级环境变量"
Write-Host ""
Write-Host '重新打开 PowerShell 后会自动生效。当前会话已可直接使用。'
