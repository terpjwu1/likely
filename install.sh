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

# Add CLAUDE.md instruction (persistent baseline rule)
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
MARKER="<!-- likely:start -->"

if [ -f "$CLAUDE_MD" ] && grep -q "$MARKER" "$CLAUDE_MD"; then
  echo "  $CLAUDE_MD already has anti-hedging rule (skipped)"
else
  # Backup existing CLAUDE.md
  if [ -f "$CLAUDE_MD" ]; then
    cp "$CLAUDE_MD" "$CLAUDE_MD.bak-likely"
    echo "  Backed up $CLAUDE_MD"
  fi
  cat >> "$CLAUDE_MD" << 'MDEOF'

<!-- likely:start -->
## Ambiguity, Uncertainty, & lack of Clarity

NEVER make assumptions or guesses when information is unclear, uncertain, or ambiguous. First, leverage tools, skills, and/or plugins to collect information and evidence, or if needed, deploy a team of research agents. You may always ask the user to help clarify information, it's better to ask the user instead of assuming or guessing, as assumptions or guesses can waste considerable time and effort.
<!-- likely:end -->
MDEOF
  echo "  Added anti-hedging rule to $CLAUDE_MD"
fi

echo ""
echo "Done. Restart Claude Code to activate."
echo ""
echo "Two layers installed:"
echo "  1. CLAUDE.md rule — prevents hedging proactively (read at session start)"
echo "  2. Hooks — catches violations that slip through and forces verification"
echo ""
echo "To uninstall:"
echo "  cp $SETTINGS.bak-likely $SETTINGS"
echo "  rm $HOOKS_DIR/hedge-detector.js $HOOKS_DIR/hedge-enforcer.js"
echo "  sed -i '' '/<!-- likely:start -->/,/<!-- likely:end -->/d' $CLAUDE_MD"
