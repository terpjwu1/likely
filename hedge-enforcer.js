#!/usr/bin/env node
// UserPromptSubmit hook: reads session-scoped signal, injects corrective context

const fs = require('fs');
const path = require('path');
const os = require('os');

const SIGNAL_DIR = path.join(os.homedir(), '.claude', 'hooks', 'signals');
const STALE_MS = 5 * 60 * 1000; // 5 min TTL

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => raw += chunk);
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(raw);
    const sessionId = input.session_id || 'unknown';
    const signalPath = path.join(SIGNAL_DIR, `hedge-${sessionId}.json`);

    if (!fs.existsSync(signalPath)) return;

    const signal = JSON.parse(fs.readFileSync(signalPath, 'utf8'));

    // Expire stale signals
    if (Date.now() - signal.timestamp > STALE_MS) {
      fs.unlinkSync(signalPath);
      return;
    }

    if (signal.detected) {
      const words = signal.words.join(', ');
      const severity = signal.severity;

      let guidance;
      if (severity === 'high') {
        guidance = `CRITICAL: Your previous response contained heavy hedging (${words}, ${signal.count} instances). You are operating on ASSUMPTIONS rather than verified facts. You MUST do the following before responding to this message:
1. Identify the specific claims you hedged on
2. For EACH hedged claim: use your tools to VERIFY it right now — read the relevant file, grep for the function, run a test, check the docs
3. After verifying, state what you found: "I confirmed X by reading [file]" or "I could not verify X because [reason]"
4. Do NOT proceed with unverified assumptions. If you cannot verify, say so explicitly and ask the user what they know.

Research first, then answer. Never guess when you can look.`;
      } else {
        guidance = `Note: Your previous response used hedging language (${words}). Before answering this message, quickly verify any assumptions you made — read the relevant code, check the actual state. If you said something "likely" works, confirm it actually does. State what you verified and how.`;
      }

      console.log(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: "UserPromptSubmit",
          additionalContext: guidance
        }
      }));

      // Consume the signal
      fs.unlinkSync(signalPath);
    }
  } catch (e) {
    process.stderr.write(`hedge-enforcer error: ${e.message}\n`);
  }
});
