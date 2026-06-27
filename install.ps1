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

# Add CLAUDE.md instruction (persistent baseline rule)
$ClaudeMd = "$env:USERPROFILE\.claude\CLAUDE.md"
$Marker = "<!-- likely:start -->"
$Rule = @"

<!-- likely:start -->
## Ambiguity, Uncertainty, & lack of Clarity

NEVER make assumptions or guesses when information is unclear, uncertain, or ambiguous. First, leverage tools, skills, and/or plugins to collect information and evidence, or if needed, deploy a team of research agents. You may always ask the user to help clarify information, it's better to ask the user instead of assuming or guessing, as assumptions or guesses can waste considerable time and effort.
<!-- likely:end -->
"@

if ((Test-Path $ClaudeMd) -and (Select-String -Path $ClaudeMd -Pattern $Marker -SimpleMatch -Quiet)) {
    Write-Host "  $ClaudeMd already has anti-hedging rule (skipped)"
} else {
    # Backup existing CLAUDE.md
    if (Test-Path $ClaudeMd) {
        Copy-Item $ClaudeMd "$ClaudeMd.bak-likely"
        Write-Host "  Backed up $ClaudeMd"
    }
    Add-Content -Path $ClaudeMd -Value $Rule -Encoding UTF8
    Write-Host "  Added anti-hedging rule to $ClaudeMd"
}

Write-Host ""
Write-Host "Done. Restart Claude Code to activate."
Write-Host ""
Write-Host "Two layers installed:"
Write-Host "  1. CLAUDE.md rule - prevents hedging proactively (read at session start)"
Write-Host "  2. Hooks - catches violations that slip through and forces verification"
Write-Host ""
Write-Host "To uninstall:"
Write-Host "  Copy-Item '$Settings.bak-likely' '$Settings'"
Write-Host "  Remove-Item '$HooksDir\hedge-detector.js', '$HooksDir\hedge-enforcer.js'"
Write-Host "  (Get-Content '$ClaudeMd') -replace '(?s)<!-- likely:start -->.*?<!-- likely:end -->\r?\n?', '' | Set-Content '$ClaudeMd' -Encoding UTF8"
