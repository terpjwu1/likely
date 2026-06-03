# likely — install anti-hedging hooks for Claude Code (Windows)

$ErrorActionPreference = "Stop"

$Repo = "https://raw.githubusercontent.com/terpjwu1/likely/main"
$HooksDir = "$env:USERPROFILE\.claude\hooks"
$SignalsDir = "$HooksDir\signals"
$Settings = "$env:USERPROFILE\.claude\settings.json"

Write-Host "Installing likely..."

# Create directories
New-Item -ItemType Directory -Force -Path $HooksDir | Out-Null
New-Item -ItemType Directory -Force -Path $SignalsDir | Out-Null

# Download hooks
Invoke-WebRequest -Uri "$Repo/hedge-detector.js" -OutFile "$HooksDir\hedge-detector.js"
Invoke-WebRequest -Uri "$Repo/hedge-enforcer.js" -OutFile "$HooksDir\hedge-enforcer.js"
Write-Host "  Downloaded hooks to $HooksDir"

# Check settings
if (-not (Test-Path $Settings)) {
    Write-Host "  ERROR: $Settings not found. Is Claude Code installed?"
    exit 1
}

# Backup
Copy-Item $Settings "$Settings.bak-likely"
Write-Host "  Backed up settings to $Settings.bak-likely"

# Inject hooks using node
$DetectorCmd = "node " + ($HooksDir + "\hedge-detector.js").Replace("\", "/")
$EnforcerCmd = "node " + ($HooksDir + "\hedge-enforcer.js").Replace("\", "/")

$NodeScript = @"
const fs = require('fs');
const settingsPath = process.argv[1];
const detectorCmd = process.argv[2];
const enforcerCmd = process.argv[3];
const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));

if (!settings.hooks) settings.hooks = {};

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
"@

node -e $NodeScript -- $Settings $DetectorCmd $EnforcerCmd

Write-Host "  Registered hooks in settings.json"
Write-Host ""
Write-Host "Done. Restart Claude Code to activate."
Write-Host "To uninstall: Copy-Item '$Settings.bak-likely' '$Settings'"
