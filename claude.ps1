$ClaudeDir = Join-Path $HOME ".claude"
$SettingsFile = Join-Path $ClaudeDir "settings.json"

New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
if (-not (Test-Path $SettingsFile)) {
    Set-Content -Path $SettingsFile -Value '{}' -Encoding UTF8
}

$content = Get-Content $SettingsFile -Raw -ErrorAction Stop
if ([string]::IsNullOrWhiteSpace($content)) {
    $json = @{}
} else {
    try {
        $json = $content | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    }
    catch {
        throw "错误：$SettingsFile 不是合法 JSON，无法自动修改。"
    }
}

if ($null -eq $json) {
    $json = @{}
}

if ($json.ContainsKey('env')) {
    if ($json.env -isnot [System.Collections.IDictionary]) {
        throw "错误：$SettingsFile 中的 env 字段不是 JSON 对象。"
    }
    $envMap = @{}
    foreach ($key in $json.env.Keys) {
        $envMap[$key] = [string]$json.env[$key]
    }
} else {
    $envMap = @{}
}

$envMap['ANTHROPIC_AUTH_TOKEN'] = 'XIXU_API_KEY'
$envMap['ANTHROPIC_BASE_URL'] = 'https://api.xi-xu.me'
$envMap['ANTHROPIC_DEFAULT_HAIKU_MODEL'] = 'gpt-5.4'
$envMap['ANTHROPIC_DEFAULT_OPUS_MODEL'] = 'gpt-5.4'
$envMap['ANTHROPIC_DEFAULT_SONNET_MODEL'] = 'gpt-5.4'
$envMap['CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC'] = '1'
$envMap['CLAUDE_CODE_SUBAGENT_MODEL'] = 'gpt-5.4'

$json['env'] = $envMap

$jsonText = $json | ConvertTo-Json -Depth 100
Set-Content -Path $SettingsFile -Value $jsonText -Encoding UTF8

Write-Host "已完成：更新 $SettingsFile"
Write-Host "已写入/合并 env 配置："
Write-Host "  - ANTHROPIC_AUTH_TOKEN = XIXU_API_KEY"
Write-Host "  - ANTHROPIC_BASE_URL = https://api.xi-xu.me"
Write-Host "  - 默认模型 = gpt-5.4"
