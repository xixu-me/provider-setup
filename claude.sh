#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

mkdir -p "$CLAUDE_DIR"
if [[ ! -f "$SETTINGS_FILE" ]]; then
  printf '{}\n' > "$SETTINGS_FILE"
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "错误：需要 python3 来安全更新 JSON 文件。" >&2
  exit 1
fi

python3 - "$SETTINGS_FILE" <<'PY'
import json
import sys
from pathlib import Path

settings_path = Path(sys.argv[1])
raw = settings_path.read_text(encoding='utf-8').strip()

if not raw:
    data = {}
else:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        raise SystemExit(f"错误：{settings_path} 不是合法 JSON，无法自动修改。\n{e}")

if not isinstance(data, dict):
    raise SystemExit(f"错误：{settings_path} 顶层必须是 JSON 对象。")

env = data.get("env")
if env is None:
    env = {}
elif not isinstance(env, dict):
    raise SystemExit(f"错误：{settings_path} 中的 env 字段不是 JSON 对象。")

env.update({
    "ANTHROPIC_AUTH_TOKEN": "XIXU_API_KEY",
    "ANTHROPIC_BASE_URL": "https://api.xi-xu.me",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "gpt-5.4",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "gpt-5.4",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "gpt-5.4",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "CLAUDE_CODE_SUBAGENT_MODEL": "gpt-5.4"
})

data["env"] = env
settings_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding='utf-8')
PY

echo "已完成：更新 $SETTINGS_FILE"
echo "已写入/合并 .env 配置："
echo "  - ANTHROPIC_AUTH_TOKEN = XIXU_API_KEY"
echo "  - ANTHROPIC_BASE_URL = https://api.xi-xu.me"
echo "  - 默认模型 = gpt-5.4"
