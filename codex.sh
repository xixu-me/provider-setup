#!/bin/sh
# Configure Codex CLI for Xi Xu's AI Inference.
set -eu

brand="Xi Xu's AI Inference"
provider_id="xixu"
base_url="https://api.xi-xu.me/v1"
model_catalog_url="https://api.xi-xu.me/v1/models"
env_key="XIXU_API_KEY"
default_model="gpt-5.5"

if [ -z "${HOME:-}" ]; then
  echo "HOME is not set." >&2
  exit 1
fi

CONFIG_DIR="${CODEX_HOME:-$HOME/.codex}"
codex_dir="$CONFIG_DIR"
cfg="$codex_dir/config.toml"
env_file="$codex_dir/xixu.env"
timestamp=$(date +%Y%m%d%H%M%S)
stty_orig=""
tmp_cfg=""
top_cfg=""
rest_cfg=""
tmp_profile=""
tmp_features=""

cleanup() {
  if [ -n "$stty_orig" ]; then
    stty "$stty_orig" 2>/dev/null || true
    stty_orig=""
  fi
  rm -f ${tmp_cfg:+"$tmp_cfg"} ${top_cfg:+"$top_cfg"} ${rest_cfg:+"$rest_cfg"} ${tmp_profile:+"$tmp_profile"} ${tmp_features:+"$tmp_features"}
}
trap cleanup 0
trap 'cleanup; exit 1' HUP INT TERM

mkdir -p "$codex_dir"

if [ -f "$cfg" ]; then
  cp "$cfg" "$cfg.bak.$timestamp"
else
  : > "$cfg"
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
printf "XIXU_API_KEY='%s'\n" "$api_key_escaped" > "$env_file"
chmod 600 "$env_file"
unset api_key api_key_escaped

tmp_cfg="$cfg.tmp.$$"
top_cfg="$cfg.top.$$"
rest_cfg="$cfg.rest.$$"

awk '
  BEGIN { skip = 0; in_table = 0 }
  /^[[:space:]]*\[model_providers\.xixu\][[:space:]]*$/ { skip = 1; next }
  /^[[:space:]]*\[/ { skip = 0; in_table = 1 }
  skip == 1 { next }
  in_table == 0 && /^[[:space:]]*(model_provider|model|model_reasoning_effort|service_tier|approval_policy|approvals_reviewer)[[:space:]]*=/ { next }
  { print }
' "$cfg" > "$tmp_cfg"

: > "$top_cfg"
: > "$rest_cfg"
awk -v top_cfg="$top_cfg" -v rest_cfg="$rest_cfg" '
  /^[[:space:]]*\[/ { in_tables = 1 }
  in_tables == 0 { print > top_cfg; next }
  { print > rest_cfg }
' "$tmp_cfg"

append_trimmed_file() {
  awk '
    NF { seen = 1; last = NR }
    seen { lines[NR] = $0 }
    END {
      for (i = 1; i <= last; i++) {
        if (i in lines) print lines[i]
      }
    }
  ' "$1"
}

{
  cat <<EOF
model_provider = "$provider_id"
model = "$default_model"
model_reasoning_effort = "xhigh"
service_tier = "fast"
approvals_reviewer = "user"
EOF
  if [ -s "$top_cfg" ]; then
    printf "\n"
    append_trimmed_file "$top_cfg"
  fi
  cat <<EOF

[model_providers.$provider_id]
name = "$brand"
base_url = "$base_url"
model_catalog_url = "$model_catalog_url"
env_key = "$env_key"
wire_api = "responses"
disable_response_storage = true
EOF
  if [ -s "$rest_cfg" ]; then
    printf "\n"
    append_trimmed_file "$rest_cfg"
  fi
} > "$cfg"

# Ensure Codex model discovery is enabled without duplicate or discarded feature settings.
tmp_features="$cfg.features.$$"
awk '
  BEGIN { in_features = 0; feature_seen = 0; feature_key = 0 }
  /^[[:space:]]*\[features\][[:space:]]*$/ {
    if (in_features && !feature_key) { print "api_key_model_discovery = true"; feature_key = 1 }
    in_features = 1; feature_seen = 1; print; next
  }
  /^[[:space:]]*\[/ {
    if (in_features && !feature_key) { print "api_key_model_discovery = true"; feature_key = 1 }
    in_features = 0
  }
  in_features && /^[[:space:]]*api_key_model_discovery[[:space:]]*=/ {
    if (!feature_key) print "api_key_model_discovery = true"
    feature_key = 1; next
  }
  { print }
  END {
    if (in_features && !feature_key) print "api_key_model_discovery = true"
    if (!feature_seen) print "\n[features]\napi_key_model_discovery = true"
  }
' "$cfg" > "$tmp_features"
mv "$tmp_features" "$cfg"
tmp_features=""

shell_name=$(basename "${SHELL:-}")
case "$shell_name" in
  zsh) profile="$HOME/.zshrc" ;;
  bash) profile="$HOME/.bashrc" ;;
  *) profile="$HOME/.profile" ;;
esac

touch "$profile"
cp "$profile" "$profile.bak.$timestamp"
tmp_profile="$profile.tmp.$$"
start="# >>> Xi Xu's AI Inference Codex >>>"
end="# <<< Xi Xu's AI Inference Codex <<<"

awk -v start="$start" -v end="$end" '
  $0 == start { skip = 1; next }
  $0 == end { skip = 0; next }
  skip != 1 { print }
' "$profile" > "$tmp_profile"

cat >> "$tmp_profile" <<'EOF'

# >>> Xi Xu's AI Inference Codex >>>
unalias codex 2>/dev/null || true
unset -f codex 2>/dev/null || true
_xixu_codex_bin=$(command -v codex 2>/dev/null || true)

codex() (
  printf "\nXi Xu's AI Inference\n"
  printf "%s\n" "----------------------"

  if [ -z "$_xixu_codex_bin" ] || [ ! -x "$_xixu_codex_bin" ]; then
    echo "Codex CLI not found. Install Codex CLI first, then restart the terminal." >&2
    return 127
  fi
  _xixu_codex_home="${CODEX_HOME:-$HOME/.codex}"
  if [ ! -r "$_xixu_codex_home/xixu.env" ]; then
    echo "Missing $_xixu_codex_home/xixu.env. Run the setup script again." >&2
    return 1
  fi

  . "$_xixu_codex_home/xixu.env"
  export XIXU_API_KEY
  "$_xixu_codex_bin" "$@"
)
# <<< Xi Xu's AI Inference Codex <<<
EOF

mv "$tmp_profile" "$profile"
tmp_profile=""

echo
echo "Done."
echo "Config: $cfg"
echo "Credentials: $env_file (mode 600)"
echo "Profile: $profile"
echo "Restart your terminal, or run: . \"$profile\""
echo "Then run: codex"
