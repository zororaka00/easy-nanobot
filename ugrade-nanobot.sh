#!/usr/bin/env bash
set -euo pipefail

# ugrade-nanobot.sh
# Simple upgrade script for nanobot installation maintained via 'uv'.
# Stops tmux, upgrades nanobot from the GitHub repo, and restarts the gateway.

echo "Stopping all tmux sessions..."
if command -v tmux >/dev/null 2>&1; then
  tmux kill-server || true
else
  echo "tmux not installed or not found in PATH. Continuing..."
fi

echo "Upgrading nanobot via uv..."
if command -v uv >/dev/null 2>&1; then
  uv tool install --upgrade git+https://github.com/HKUDS/nanobot.git
else
  echo "Error: 'uv' command not found. Please ensure uv is installed and in PATH." >&2
  exit 1
fi

echo "Starting nanobot gateway in a detached tmux session 'nanobot-gateway'..."
if command -v tmux >/dev/null 2>&1; then
  tmux new -d -s nanobot-gateway "nanobot gateway"
  echo "Started tmux session 'nanobot-gateway'."
else
  echo "tmux not available; please start the gateway manually: nanobot gateway" >&2
fi

echo "Done."
