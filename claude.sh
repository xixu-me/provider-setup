#!/bin/sh
# Configure Claude Code for Xi Xu's AI Inference.
set -eu

if [ -z "${HOME:-}" ]; then
  echo "HOME is not set." >&2
  exit 1
fi

SETTINGS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
claude_dir="$SETTINGS_DIR"
env_file="$claude_dir/xixu.env"
default_model="gpt-5.5"
timestamp=$(date +%Y%m%d%H%M%S)
stty_orig=""
tmp_profile=""

cleanup() {
  if [ -n "$stty_orig" ]; then
    stty "$stty_orig" 2>/dev/null || true
    stty_orig=""
  fi
  rm -f ${tmp_profile:+"$tmp_profile"}
}
trap cleanup 0
trap 'cleanup; exit 1' HUP INT TERM

mkdir -p "$claude_dir"
if [ -f "$env_file" ]; then
  cp "$env_file" "$env_file.bak.$timestamp"
fi

printf "Enter your Xi Xu API key: "
if [ -t 0 ]; then
  stty_orig=$(stty -g 2>/dev/null || true)
  stty -echo 2>/dev/null || true
fi
IFS= read -r api_key
if [ -n "$stty_orig" ]; then
  stty "$stty_orig" 2>/dev/null || true
  stty_orig=""
  printf "\n"
fi

if [ -z "$api_key" ]; then
  echo "API key is required." >&2
  exit 1
fi

escape_single_quotes() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g"
}

api_key_escaped=$(escape_single_quotes "$api_key")
{
  printf "XIXU_API_KEY='%s'\n" "$api_key_escaped"
  printf "XIXU_MODEL='%s'\n" "$default_model"
} > "$env_file"
chmod 600 "$env_file"
unset api_key api_key_escaped

shell_name=$(basename "${SHELL:-}")
case "$shell_name" in
  zsh) profile="$HOME/.zshrc" ;;
  bash) profile="$HOME/.bashrc" ;;
  *) profile="$HOME/.profile" ;;
esac

touch "$profile"
cp "$profile" "$profile.bak.$timestamp"
tmp_profile="$profile.tmp.$$"
start="# >>> Xi Xu's AI Inference Claude Code >>>"
end="# <<< Xi Xu's AI Inference Claude Code <<<"

awk -v start="$start" -v end="$end" '
  $0 == start { skip = 1; next }
  $0 == end { skip = 0; next }
  skip != 1 { print }
' "$profile" > "$tmp_profile"

cat >> "$tmp_profile" <<'EOF'

# >>> Xi Xu's AI Inference Claude Code >>>
unalias claude 2>/dev/null || true
unset -f claude 2>/dev/null || true
_xixu_claude_bin=$(command -v claude 2>/dev/null || true)

claude() (
  printf "\nXi Xu's AI Inference\n"
  printf "%s\n" "----------------------"

  if [ -z "$_xixu_claude_bin" ] || [ ! -x "$_xixu_claude_bin" ]; then
    echo "Claude Code not found. Install Claude Code first, then restart the terminal." >&2
    return 127
  fi
  _xixu_claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  if [ ! -r "$_xixu_claude_dir/xixu.env" ]; then
    echo "Missing $_xixu_claude_dir/xixu.env. Run the setup script again." >&2
    return 1
  fi

  . "$_xixu_claude_dir/xixu.env"
  export ANTHROPIC_BASE_URL="https://api.xi-xu.me"
  export ANTHROPIC_AUTH_TOKEN="$XIXU_API_KEY"
  unset ANTHROPIC_API_KEY
  unset CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY
  export ANTHROPIC_MODEL="$XIXU_MODEL"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="$XIXU_MODEL"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="$XIXU_MODEL"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="$XIXU_MODEL"
  export ANTHROPIC_DEFAULT_FABLE_MODEL="$XIXU_MODEL"
  export CLAUDE_CODE_SUBAGENT_MODEL="$XIXU_MODEL"
  export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
  "$_xixu_claude_bin" "$@"
)
# <<< Xi Xu's AI Inference Claude Code <<<
EOF

mv "$tmp_profile" "$profile"
tmp_profile=""

echo
echo "Done."
echo "Credentials: $env_file (mode 600)"
echo "Profile: $profile"
echo "Restart your terminal, or run: . \"$profile\""
echo "Then run: claude"
