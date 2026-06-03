#!/usr/bin/env node
// Stop hook: detects hedging in assistant response, writes session-scoped signal file

const fs = require('fs');
const path = require('path');
const os = require('os');

const HEDGE_WORDS = /\b(likely|potentially|probably|possibly|presumably|may be|might be|could be|seems to|appears to)\b/gi;
const SIGNAL_DIR = path.join(os.homedir(), '.claude', 'hooks', 'signals');

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => raw += chunk);
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(raw);
    const sessionId = input.session_id || 'unknown';
    const msg = input.last_assistant_message || '';
    const signalPath = path.join(SIGNAL_DIR, `hedge-${sessionId}.json`);

    const matches = [...msg.matchAll(HEDGE_WORDS)].map(m => m[0].toLowerCase());
    const unique = [...new Set(matches)];

    if (unique.length > 0) {
      fs.mkdirSync(SIGNAL_DIR, { recursive: true });
      const signal = {
        detected: true,
        words: unique,
        count: matches.length,
        timestamp: Date.now(),
        sessionId,
        severity: matches.length >= 3 ? 'high' : 'medium'
      };
      const tmp = signalPath + '.tmp';
      fs.writeFileSync(tmp, JSON.stringify(signal));
      fs.renameSync(tmp, signalPath);
    }
  } catch (e) {
    process.stderr.write(`hedge-detector error: ${e.message}\n`);
  }
});
