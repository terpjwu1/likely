# TODO

## Cross-tool support (hooks portability)

Goal: bring the detector → signal → enforcer loop to other agentic coding tools that
have (or are gaining) lifecycle-hook support. Claude Code is currently hardcoded in the
event names (`Stop`, `UserPromptSubmit`), the payload shape (`last_assistant_message`,
`session_id`), the context-injection format (`additionalContext` JSON on stdout), and
the install target (`~/.claude/`).

- [ ] **Extract a tool-agnostic core** — split `hedge-detector.js` / `hedge-enforcer.js`
      into shared logic (regex matching, signal file read/write, severity, TTL) plus
      thin per-tool adapters that translate each tool's event payload in and its
      context-injection format out.
- [ ] **GitHub Copilot CLI / Copilot coding agent** — research its hooks/config surface;
      map equivalents for the Stop and UserPromptSubmit events; determine whether it can
      inject context into the next turn or only observe. Write an adapter + install path.
- [ ] **Pi / oh-my-pi** — research Pi's extension/hook mechanism and whether oh-my-pi is
      the right distribution channel (ship `likely` as an oh-my-pi package?).
- [ ] **OpenAI Codex CLI** — research current hook/notify support in `config.toml`;
      verify whether the response text is available to a post-turn hook and whether
      context can be injected pre-turn. (The Codex plugin already runs alongside Claude
      Code locally — good first test bed.)
- [ ] **Cursor** — research Cursor's hooks support (agent lifecycle hooks); adapter +
      install docs if the injection path exists.
- [ ] **Capability matrix in README** — per tool: post-response event? pre-prompt event?
      context injection? session id available? So users know what degree of the feedback
      loop each tool supports (full loop vs. detect-only).
- [ ] **Unified installer** — `install.sh --tool claude|copilot|codex|cursor|pi` (or
      auto-detect installed tools), each writing the right config file. Keep per-tool
      uninstall instructions.
- [ ] **Port the CLAUDE.md rule** — each tool has its own persistent-instructions file
      (AGENTS.md for Codex, .cursorrules / Cursor rules, copilot-instructions.md).
      Install the same marker-wrapped rule into the right file per tool.

## Detection improvements (from eval 3 false-positive patterns)

- [ ] Scope detection to the AI's own prose only — 4 FPs from context bleed (word in
      quoted text, diagrams, or surrounding context).
- [ ] Don't fire when the hedge word is part of a URL/proper noun (e.g. this repo's own
      name) — require the word in a grammatical clause.
- [ ] Don't fire inside quotation marks / illustrative examples.
- [ ] Exempt domains where hedging is structurally correct (legal, privacy, caching
      behavior) — 5 FPs were appropriate epistemic humility.
- [ ] Exclude session-summary/recap messages (factual recaps of prior evals).

## Evals

- [ ] Re-run the eval pipeline after the FP fixes land; target FP rate < 20%.
- [ ] Once a second tool is supported, run a comparative eval (does the loop change
      behavior equally well in Codex/Copilot?).
