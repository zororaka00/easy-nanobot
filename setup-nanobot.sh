#!/usr/bin/env bash
set -euo pipefail

# setup-nanobot.sh
# Automated installer and configurator for nanobot (uv / nanobot-ai)
# This script reads configuration from $HOME/easy-nanobot/config.json

EASY_DIR="$HOME/easy-nanobot"
CFG_FILE="$EASY_DIR/config.json"
SAMPLE_FILE="$EASY_DIR/config.json.example"

echo "Starting nanobot setup script. This script will perform system updates, install uv, install nanobot-ai, run onboarding, merge configuration into ~/.nanobot/config.json, install tmux and start the gateway in a tmux session."

# Ensure easy dir exists
mkdir -p "$EASY_DIR"

# If config.json doesn't exist, create a sample and instruct the user to edit it
if [ ! -f "$CFG_FILE" ]; then
  cat > "$SAMPLE_FILE" <<'JSON'
{
  "agents": {
    "defaults": {
      "model": "openrouter/gpt-4o-mini"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "YOUR_TELEGRAM_BOT_TOKEN_HERE",
      "allowFrom": [123456789]
    }
  },
  "providers": {
    "openrouter": {
      "apiKey": "YOUR_OPENROUTER_API_KEY_HERE"
    }
  },
  "tools": {
    "web": {
      "search": {
        "apiKey": "YOUR_WEB_SEARCH_API_KEY_HERE"
      }
    }
  }
}
JSON
  # create a copy the user can edit
  cp -n "$SAMPLE_FILE" "$CFG_FILE" || true
  echo
  echo "A configuration template has been created at: $CFG_FILE"
  echo "Please edit $CFG_FILE and fill in the required values (Telegram token, whitelist user ids, OpenRouter API key, web_search API key, model if you want to change)."
  echo "Once you have edited and saved $CFG_FILE, re-run this script: bash $0"
  exit 0
fi

# Confirm continuation
read -p "Config file found at $CFG_FILE. Continue with installation? (y/N) " confirm
if [[ "${confirm,,}" != "y" ]]; then
  echo "Aborted by user. Edit $CFG_FILE if needed and re-run the script.";
  exit 1
fi

# 1) System update
echo "1) Updating system packages..."
sudo apt update && sudo apt upgrade -y

# 2) Install curl & install uv
echo "2) Installing curl and uv (astral 'uv')..."
sudo apt install -y curl ca-certificates

# Install uv via the recommended installer
if curl -LsSf https://astral.sh/uv/install.sh | sh; then
  echo "uv installer finished."
else
  echo "uv installer failed or returned non-zero exit code. Please inspect output and install uv manually.";
fi

# Try to source common uv shell helpers and ensure ~/.local/bin is in PATH for this session
UV_SOURCED=false
if [ -f "$HOME/.local/share/uv/uv.sh" ]; then
  # shellcheck source=/dev/null
  source "$HOME/.local/share/uv/uv.sh" && UV_SOURCED=true
fi
if ! $UV_SOURCED && [ -f "$HOME/.uv/uv.sh" ]; then
  # shellcheck source=/dev/null
  source "$HOME/.uv/uv.sh" && UV_SOURCED=true
fi
export PATH="$HOME/.local/bin:$PATH"

if ! command -v uv >/dev/null 2>&1; then
  echo "Warning: 'uv' command not found in PATH. You may need to open a new shell or add ~/.local/bin to your PATH. The script will continue but 'uv' steps may fail.";
else
  echo "'uv' is available.";
fi

# 3) Ensure python3 is installed
echo "3) Checking Python 3..."
if command -v python3 >/dev/null 2>&1; then
  echo "Found python3: $(python3 --version)"
else
  echo "python3 not found. Installing python3, python3-venv, python3-pip..."
  sudo apt install -y python3 python3-venv python3-pip
fi

# 4) Install nanobot-ai via uv
echo "4) Installing nanobot-ai via 'uv' if available..."
if command -v uv >/dev/null 2>&1; then
  uv tool install nanobot-ai || echo "uv tool install reported a non-zero exit code. You can try: uv tool install nanobot-ai";
else
  echo "Skipping uv tool install because 'uv' is not available in PATH.";
fi

# 5) Run nanobot onboard if available
echo "5) Running 'nanobot onboard' if the command is available..."
if command -v nanobot >/dev/null 2>&1; then
  nanobot onboard || echo "'nanobot onboard' completed with non-zero exit code (or requires interactive input).";
else
  echo "'nanobot' command not found in PATH. You may need to open a new shell session so your PATH is updated and retry 'nanobot onboard'.";
fi

# 6) Merge configuration into ~/.nanobot/config.json
echo "6) Merging configuration from $CFG_FILE into ~/.nanobot/config.json"
TARGET_CFG="$HOME/.nanobot/config.json"
mkdir -p "$(dirname "$TARGET_CFG")"

python3 - <<PY
import json, os, sys
from pathlib import Path

home = os.path.expanduser('~')
source = Path(os.path.expanduser('$CFG_FILE'))
target = Path(os.path.expanduser('$TARGET_CFG'))

if not source.exists():
    print('Source configuration not found: ', source)
    sys.exit(2)

# Load source
with source.open('r', encoding='utf-8') as f:
    src = json.load(f)

# Load or create target
if target.exists():
    try:
        with target.open('r', encoding='utf-8') as f:
            tgt = json.load(f)
    except Exception:
        print('Warning: existing ~/.nanobot/config.json could not be parsed. Overwriting with new structure.')
        tgt = {}
else:
    tgt = {}

# Helper to ensure nested path exists
def ensure(d, *keys):
    for k in keys:
        if k not in d or not isinstance(d[k], dict):
            d[k] = {}
        d = d[k]
    return d

# Map values from source to target using expected structure
#  - model -> agents.defaults.model
#  - telegram token -> channels.telegram.token and channels.telegram.enabled = true
#  - telegram allowFrom -> channels.telegram.allowFrom
#  - openrouter apiKey -> providers.openrouter.apiKey
#  - web search apiKey -> tools.web.search.apiKey

# Model
model = src.get('agents', {}).get('defaults', {}).get('model') or src.get('model')
if model:
    ensure(tgt, 'agents', 'defaults')
    tgt['agents']['defaults']['model'] = model

# Telegram
tg = src.get('channels', {}).get('telegram', {})
if tg:
    ensure(tgt, 'channels', 'telegram')
    if 'token' in tg and tg['token']:
        tgt['channels']['telegram']['token'] = tg['token']
        tgt['channels']['telegram']['enabled'] = True
    # allowFrom or whitelist
    allow = tg.get('allowFrom') or tg.get('whitelist')
    if allow:
        # attempt to coerce to list
        if isinstance(allow, list):
            tgt['channels']['telegram']['allowFrom'] = allow
        else:
            # comma separated string
            tgt['channels']['telegram']['allowFrom'] = [x.strip() for x in str(allow).split(',') if x.strip()]

# OpenRouter
orv = src.get('providers', {}).get('openrouter') or {}
or_key = orv.get('apiKey') or orv.get('api_key') or src.get('openrouter_api_key')
if or_key:
    ensure(tgt, 'providers', 'openrouter')
    tgt['providers']['openrouter']['apiKey'] = or_key

# Web search
ws = src.get('tools', {}).get('web', {}).get('search') or {}
ws_key = ws.get('apiKey') or ws.get('api_key') or src.get('tools', {}).get('web', {}).get('search', {}).get('api_key')
if ws_key:
    ensure(tgt, 'tools', 'web', 'search')
    tgt['tools']['web']['search']['apiKey'] = ws_key

# Write back target
with target.open('w', encoding='utf-8') as f:
    json.dump(tgt, f, indent=2, ensure_ascii=False)

print('Merged configuration saved to', target)
PY

# 7) Install tmux
echo "7) Installing tmux..."
sudo apt install -y tmux

# 8) Start nanobot gateway in tmux
echo "8) Starting nanobot gateway in tmux session 'nanobot-gateway'"
if command -v nanobot >/dev/null 2>&1; then
  if tmux has-session -t nanobot-gateway 2>/dev/null; then
    echo "tmux session 'nanobot-gateway' already exists. Killing and restarting..."
    tmux kill-session -t nanobot-gateway || true
  fi
  # Start detached tmux session running the gateway
  tmux new -d -s nanobot-gateway "nanobot gateway"
  echo "Nanobot gateway started in tmux session 'nanobot-gateway'. Use: tmux attach -t nanobot-gateway"
else
  echo "'nanobot' command not available; cannot start gateway. Please ensure nanobot is installed and in PATH, then run: tmux new -d -s nanobot-gateway \"nanobot gateway\""
fi

# 9) Done
echo "9) Done. Review ~/.nanobot/config.json and the easy-nanobot/config.json you provided. If you need adjustments, edit and re-run this script."
