---
name: voice-update
description: Use when the agent should give a spoken voice update—e.g. after finishing a task or when the user asks for a spoken summary. Speaks a short summary via pocket-tts.
---

# Voice Update Skill

Provide spoken audio feedback using pocket-tts (say script).

## When to Use

- When finishing a task and you want to give a brief spoken summary
- When the user asks for a spoken summary or voice update
- For important status updates that benefit from audio

## How to Use

1. Summarize what was accomplished in 1–2 short, conversational sentences.
2. Call the say script with that summary.

## Calling the Say Script

Use the say script from the plugin. Standard install (XDG): `$XDG_DATA_HOME/voice-plugin-cursor/scripts/say` (default `~/.local/share/voice-plugin-cursor/scripts/say`). If `VOICE_PLUGIN_ROOT` is set, use that.

```bash
"${VOICE_PLUGIN_ROOT:-$HOME/.local/share/voice-plugin-cursor}/scripts/say" "Your summary here"
```

Examples:

```bash
~/.local/share/voice-plugin-cursor/scripts/say "I've fixed the bug in the login handler and added the unit tests."
~/.local/share/voice-plugin-cursor/scripts/say --voice azure "Task completed successfully."
```

## Summary Guidelines

- 1–2 sentences max; conversational, not robotic
- Match the user's tone
- Focus on what was accomplished; avoid code, paths, and jargon
- Examples: "I've updated the config and restarted the server." / "Tests are passing; I fixed three type errors."

## Notes

- The say script can auto-start the pocket-tts server (first run may take ~30–60s).
- Requires `uvx` and `afplay` (macOS), `aplay` or `paplay` (Linux), or similar.
