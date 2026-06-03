# likely

A Claude Code hook that catches AI hedging, making ungrounded assumptions, and forces verification as a way for self-healing.

## The Problem

LLMs hedge constantly. Words like "likely", "potentially", "probably" appear in **35% of sessions** — not because the model is uncertain, but because it's trained to sound non-committal. This is dangerous in a coding context: when the AI says "this will likely work," it might be guessing rather than verifying.

After analyzing 14,000+ messages across Claude Code, Codex, and Cortex sessions:

![AI Hedging Analysis — How fast does the AI start hedging?](dashboard-hedging.png)

| Word | % Sessions | Median Turn (first use) | Avg Turn |
|------|-----------|------------------------|----------|
| likely | 34.5% | **6** | 17.5 |
| potentially | 14.2% | **2** | 10.2 |
| probably | 11.5% | 26 | 59.9 |
| possibly | 3.5% | 108 | 86.4 |
| presumably | 2.7% | 44 | 45.5 |

The AI uses "potentially" by **turn 2** (median). "Likely" shows up by **turn 6**. These aren't genuine expressions of uncertainty — they're verbal tics that mask whether the AI actually verified its claims.

## The Solution

Two Claude Code hooks forming a feedback loop:

1. **`hedge-detector.js`** (Stop hook) — After each AI response, scans for hedging words. If found, writes a session-scoped signal file.

2. **`hedge-enforcer.js`** (UserPromptSubmit hook) — Before the next turn is processed, reads the signal and injects corrective context forcing the AI to **verify its assumptions using tools** (read files, grep, run tests) before responding.

```
AI responds: "this will likely work"
         │
         ▼
    Stop hook detects "likely"
    Writes signal file
         │
         ▼ (next user message)
    UserPromptSubmit hook reads signal
    Injects: "VERIFY your claims before answering"
         │
         ▼
    AI now reads files, checks code, states evidence
```

The AI doesn't just rephrase with more confidence — it's forced to **do the research** and cite what it found.

## Installation

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/terpjwu1/likely/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/terpjwu1/likely/main/install.ps1 | iex
```

Restart Claude Code after installing.

**To uninstall:**
```bash
cp ~/.claude/settings.json.bak-likely ~/.claude/settings.json
rm ~/.claude/hooks/hedge-detector.js ~/.claude/hooks/hedge-enforcer.js
```

### Manual Installation

If you prefer to configure manually, add these to your `~/.claude/settings.json` hooks section:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node ~/.claude/hooks/hedge-detector.js",
            "timeout": 5,
            "async": true
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node ~/.claude/hooks/hedge-enforcer.js",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

**Important:** The enforcer must NOT have `"async": true` — its stdout needs to be captured by Claude Code for context injection.

## How It Works

### Detection (Stop Hook)

The detector receives `last_assistant_message` from Claude Code after each response. It regex-matches against:

```
likely, potentially, probably, possibly, presumably,
may be, might be, could be, seems to, appears to
```

If matches are found, it writes a session-scoped signal file:
- Path: `~/.claude/hooks/signals/hedge-{sessionId}.json`
- Atomic write (tmp file + rename) for race safety
- Severity: `high` (3+ matches) or `medium` (1-2)

### Enforcement (UserPromptSubmit Hook)

On the next user message, the enforcer:
1. Reads the signal file for this session
2. Checks TTL (5 min expiry for stale signals)
3. If valid, outputs JSON to stdout with `additionalContext`
4. Claude Code injects this as a system reminder the AI must follow
5. Deletes the signal (consumed)

### Severity Levels

**High (3+ hedging words):**
> CRITICAL: You are operating on ASSUMPTIONS. For EACH hedged claim, use your tools to VERIFY it right now — read the file, grep for the function, run a test. State what you found.

**Medium (1-2 hedging words):**
> Note: Quickly verify assumptions you made. If you said something "likely" works, confirm it actually does.

## Design Decisions

- **Session-scoped signals** — keyed by `session_id`, not global. Multiple concurrent sessions don't interfere.
- **Atomic writes** — temp file + rename prevents partial reads.
- **5-minute TTL** — stale signals from crashed sessions auto-expire.
- **No stemming** — regex uses exact word boundaries, not NLP. Fast and predictable.
- **Feedback loop, not blocking** — hooks can't re-generate responses. Instead, the correction shapes the *next* turn. The AI learns within the session.
- **Zero dependencies** — plain Node.js, no npm packages. Just `fs`, `path`, `os`.

## Relation to Buddy Guard Mode

This project is a companion to [Buddy](https://github.com/fiorastudio/buddy) — an MCP coding companion that tracks reasoning quality via guard mode. Buddy's guard mode extracts claims from conversations and scores them by epistemic basis (empirical, deduction, research, assumption, vibes). The `likely` hooks address a complementary problem:

- **Buddy guard mode** observes reasoning *structure* — are claims well-sourced? Do they support or contradict each other?
- **likely** observes reasoning *confidence* — is the AI hedging when it should be verifying?

Together they form a two-layer quality system: Buddy watches the *what* (claim graph integrity), `likely` watches the *how* (are claims backed by evidence or just hedged guesses).

The hedging analysis data that motivated this project (35% session penetration, median turn 1 for "potentially") was collected using the same DuckDB analytics pipeline that powers Buddy's reasoning insights.

## Limitations

- Corrective context arrives on the **next turn**, not the current one. The hedged response is already shown.
- Hooks cannot force extended thinking or change effort level dynamically.
- The AI may still hedge if the corrective prompt competes with other strong context.
- Words like "might" and "could" (without "be") aren't tracked to avoid excessive false positives.

## Testing

```bash
# Test detector
echo '{"session_id":"test","last_assistant_message":"this will likely work and potentially fix it"}' | node hedge-detector.js
cat ~/.claude/hooks/signals/hedge-test.json

# Test enforcer
echo '{"session_id":"test"}' | node hedge-enforcer.js
# Should output JSON with additionalContext
```

## License

MIT
