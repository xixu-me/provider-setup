#!/usr/bin/env bash
set -euo pipefail

# 用法:
#   bash setup-xixu.sh your_api_key
# 或:
#   XIXU_API_KEY=your_api_key bash setup-xixu.sh

API_KEY="${1:-${XIXU_API_KEY:-}}"

if [[ -z "$API_KEY" ]]; then
  read -rsp "请输入 XIXU_API_KEY: " API_KEY
  echo
fi

CONFIG_DIR="${CODEX_HOME:-$HOME/.codex}"
CONFIG_FILE="$CONFIG_DIR/config.toml"

mkdir -p "$CONFIG_DIR"
touch "$CONFIG_FILE"

TMP_FILE="$(mktemp)"

awk '
BEGIN {
  in_xixu = 0
  model_provider_written = 0
}
{
  if ($0 ~ /^[[:space:]]*model_provider[[:space:]]*=/) {
    if (!model_provider_written) {
      print "model_provider = \"xixu\""
      model_provider_written = 1
    }
    next
  }

  if ($0 ~ /^\[model_providers\.xixu\][[:space:]]*$/) {
    in_xixu = 1
    next
  }

  if (in_xixu && $0 ~ /^\[.*\][[:space:]]*$/) {
    in_xixu = 0
  }

  if (!in_xixu) {
    print $0
  }
}
END {
  if (!model_provider_written) {
    print ""
    print "model_provider = \"xixu\""
  }

  print ""
  print "[model_providers.xixu]"
  print "name = \"Xi Xu'\''s AI Inference\""
  print "base_url = \"https://api.xi-xu.me/v1\""
  print "env_key = \"XIXU_API_KEY\""
}
' "$CONFIG_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$CONFIG_FILE"

export XIXU_API_KEY="$API_KEY"

SHELL_NAME="$(basename "${SHELL:-bash}")"
if [[ "$SHELL_NAME" == "zsh" ]]; then
  RC_FILE="$HOME/.zshrc"
else
  RC_FILE="$HOME/.bashrc"
fi

touch "$RC_FILE"

if grep -q '^export XIXU_API_KEY=' "$RC_FILE"; then
  sed -i.bak "s|^export XIXU_API_KEY=.*$|export XIXU_API_KEY=\"$API_KEY\"|" "$RC_FILE"
else
  {
    echo ""
    echo "# Added for Xi Xu Codex provider"
    echo "export XIXU_API_KEY=\"$API_KEY\""
  } >> "$RC_FILE"
fi

echo "已完成："
echo "1. 更新 $CONFIG_FILE"
echo "2. 设置当前会话环境变量 XIXU_API_KEY"
echo "3. 持久化到 $RC_FILE"
echo
echo "可执行：source \"$RC_FILE\""
