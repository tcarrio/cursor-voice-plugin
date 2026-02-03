#!/usr/bin/env bash
#
# Install voice plugin for Cursor IDE (global / user-level).
#
# XDG directories (voice plugin artifacts):
#   $XDG_DATA_HOME/voice-plugin-cursor/   - plugin files (hooks, scripts, say) [default ~/.local/share]
#   $XDG_CONFIG_HOME/voice-plugin-cursor/ - voice config voice.local.md [default ~/.config]
#   $XDG_STATE_HOME/voice-plugin-cursor/ - TTS server log, PID, runtime [default ~/.local/state]
#
# ~/.cursor/ only (required by Cursor):
#   ~/.cursor/hooks.json   - Cursor hooks (stop hook points at plugin in XDG_DATA_HOME)
#   ~/.cursor/commands/    - /speak command
#   ~/.cursor/skills/      - voice-update skill
#
set -e

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
CURSOR_HOME="${CURSOR_HOME:-$HOME/.cursor}"
PLUGIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/voice-plugin-cursor"
TARGET="$PLUGIN_DIR"

echo "Installing voice plugin for Cursor..."
echo "  Plugin: $TARGET (XDG_DATA_HOME)"
echo "  Cursor (required): $CURSOR_HOME (hooks, commands, skills)"
mkdir -p "$(dirname "$TARGET")" "$CURSOR_HOME"

# Plugin tree into XDG_DATA_HOME
if [[ -L "$TARGET" ]] || [[ -d "$TARGET" ]]; then
  rm -rf "$TARGET"
fi
cp -R "$REPO_ROOT" "$TARGET"
rm -f "$TARGET/install-cursor.sh" 2>/dev/null || true

# Deep-merge stop hook into ~/.cursor/hooks.json (Cursor requires it here)
HOOKS_JSON="$CURSOR_HOME/hooks.json"
HOOK_CMD="python3 $TARGET/hooks/stop_hook_cursor.py"

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required to merge hooks.json. Install it (e.g. brew install jq, nix-shell -p jq) and re-run." >&2
  exit 1
fi

HOOK_JSON=$(jq -n --arg cmd "$HOOK_CMD" '{command: $cmd, timeout: 60}')
EXISTING=$(cat "$HOOKS_JSON" 2>/dev/null || echo "{}")

if echo "$EXISTING" | jq -e '.hooks.stop[]? | select(.command | contains("stop_hook_cursor"))' &>/dev/null; then
  echo "Stop hook already present in $HOOKS_JSON"
else
  NEW_JSON=$(echo "$EXISTING" | jq --argjson hook "$HOOK_JSON" '
    .version = (.version // 1) |
    .hooks = (.hooks // {}) |
    .hooks.stop = ((.hooks.stop // []) + [$hook])
  ')
  echo "$NEW_JSON" > "$HOOKS_JSON"
  echo "Merged voice stop hook into $HOOKS_JSON"
fi

# Commands and skills (Cursor requires these under ~/.cursor)
mkdir -p "$CURSOR_HOME/commands" "$CURSOR_HOME/skills"
cp -R "$REPO_ROOT/.cursor/commands/"* "$CURSOR_HOME/commands/" 2>/dev/null || true
cp -R "$REPO_ROOT/.cursor/skills/"* "$CURSOR_HOME/skills/" 2>/dev/null || true

echo "Done. Plugin: $TARGET"
echo "Config: \${XDG_CONFIG_HOME:-~/.config}/voice-plugin-cursor/voice.local.md (created on first /speak or when hook runs)"
echo "Restart Cursor to load hooks. Use /speak and /speak stop to enable/disable."
