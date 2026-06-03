#!/bin/bash
# likely — install anti-hedging hooks for Claude Code

set -e

REPO="https://raw.githubusercontent.com/terpjwu1/likely/main"
HOOKS_DIR="$HOME/.claude/hooks"
SIGNALS_DIR="$HOOKS_DIR/signals"
SETTINGS="$HOME/.claude/settings.json"

echo "Installing likely..."

# Create directories
mkdir -p "$HOOKS_DIR" "$SIGNALS_DIR"

# Download hooks
curl -fsSL "$REPO/hedge-detector.js" -o "$HOOKS_DIR/hedge-detector.js"
curl -fsSL "$REPO/hedge-enforcer.js" -o "$HOOKS_DIR/hedge-enforcer.js"
echo "  Downloaded hooks to $HOOKS_DIR"

# Check if settings.json exists
if [ ! -f "$SETTINGS" ]; then
  echo "  ERROR: $SETTINGS not found. Is Claude Code installed?"
  exit 1
fi

# Backup settings
cp "$SETTINGS" "$SETTINGS.bak-likely"
echo "  Backed up settings to $SETTINGS.bak-likely"

# Inject hooks into settings.json
node -e "
const fs = require('fs');
const path = require('path');
const settingsPath = '$SETTINGS';
const hooksDir = '$HOOKS_DIR';
const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));

if (!settings.hooks) settings.hooks = {};

const detectorCmd = 'node ' + path.join(hooksDir, 'hedge-detector.js');
const enforcerCmd = 'node ' + path.join(hooksDir, 'hedge-enforcer.js');

if (!settings.hooks.Stop) settings.hooks.Stop = [];
const stopHasIt = settings.hooks.Stop.some(e => e.hooks?.some(h => h.command?.includes('hedge-detector')));
if (!stopHasIt) {
  const existing = settings.hooks.Stop[0];
  if (existing && existing.hooks) {
    existing.hooks.push({ type: 'command', command: detectorCmd, timeout: 5, async: true });
  } else {
    settings.hooks.Stop.push({ hooks: [{ type: 'command', command: detectorCmd, timeout: 5, async: true }] });
  }
}

if (!settings.hooks.UserPromptSubmit) settings.hooks.UserPromptSubmit = [];
const upsHasIt = settings.hooks.UserPromptSubmit.some(e => e.hooks?.some(h => h.command?.includes('hedge-enforcer')));
if (!upsHasIt) {
  const existing = settings.hooks.UserPromptSubmit[0];
  if (existing && existing.hooks) {
    existing.hooks.push({ type: 'command', command: enforcerCmd, timeout: 5 });
  } else {
    settings.hooks.UserPromptSubmit.push({ hooks: [{ type: 'command', command: enforcerCmd, timeout: 5 }] });
  }
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
"

echo "  Registered hooks in settings.json"
echo ""
echo "Done. Restart Claude Code to activate."
echo "To uninstall: cp $SETTINGS.bak-likely $SETTINGS"
