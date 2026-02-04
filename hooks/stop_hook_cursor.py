#!/usr/bin/env python3
"""
Cursor stop hook - post-completion audible summary.

When the Cursor agent stops, this hook:
1. Reads the last assistant message from the conversation transcript (if available)
2. Optionally uses headless Claude to generate a short spoken summary
3. Calls the say script to speak it
4. Returns (no block, no followup)

Uses XDG_CONFIG_HOME/voice-plugin-cursor/voice.local.md for config only.
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

# Plugin root (e.g. XDG_DATA_HOME/voice-plugin-cursor)
HOOKS_DIR = Path(__file__).resolve().parent
PLUGIN_ROOT = HOOKS_DIR.parent


def _voice_config_path() -> Path:
    """XDG config path only."""
    xdg = os.environ.get("XDG_CONFIG_HOME")
    base = Path(xdg).expanduser() if xdg else Path.home() / ".config"
    return base / "voice-plugin-cursor" / "voice.local.md"


def get_voice_config() -> tuple[bool, str, str]:
    """Read voice config from XDG_CONFIG_HOME/voice-plugin-cursor/voice.local.md.

    Returns:
        Tuple of (enabled, voice, custom_prompt)
    """
    config_file = _voice_config_path()
    if not config_file.exists():
        config_file.parent.mkdir(parents=True, exist_ok=True)
        config_file.write_text("""---
voice: eponine
enabled: true
---

# Voice Feedback Configuration

Use `/speak stop` to disable, `/speak <name>` to change voice.
""", encoding="utf-8")
        return True, "eponine", ""

    content = config_file.read_text(encoding="utf-8")

    enabled = True
    voice = "eponine"
    custom_prompt = ""

    lines = content.split("\n")
    in_frontmatter = False
    for line in lines:
        if line.strip() == "---":
            if not in_frontmatter:
                in_frontmatter = True
                continue
            else:
                break
        if in_frontmatter:
            if line.startswith("enabled:"):
                val = line.split(":", 1)[1].strip()
                enabled = val.lower() != "false"
            elif line.startswith("voice:"):
                voice = line.split(":", 1)[1].strip()
            elif line.startswith("prompt:"):
                val = line.split(":", 1)[1].strip()
                if (val.startswith('"') and val.endswith('"')) or (
                    val.startswith("'") and val.endswith("'")
                ):
                    val = val[1:-1]
                custom_prompt = val

    return enabled, voice, custom_prompt


def get_last_assistant_from_transcript(transcript_path: Path) -> str | None:
    """
    Extract the last assistant message from a Cursor transcript file.
    Handles plain text, markdown (## Assistant / ## User), or similar patterns.
    """
    if not transcript_path.is_file():
        return None
    try:
        text = transcript_path.read_text(encoding="utf-8", errors="replace")
        Path("/Users/tcarrio/Code/voice-plugin-cursor/transcript.md").write_text(
            transcript_path.name +
            "\n--------------------------------\n" +
            text,
            encoding="utf-8"
        )
    except Exception:
        return None

    if not text.strip():
        return None

    # Try markdown-style sections (## Assistant / ## User / ## Human)
    sections = re.split(r"\n(?=##\s+)", text)
    for block in reversed(sections):
        if re.match(r"^##\s+(Assistant|assistant)\s*\n", block, re.IGNORECASE):
            body = re.sub(r"^##\s+\w+\s*\n", "", block).strip()
            if body:
                return body

    # Try "Assistant:" or "assistant:" line prefix
    for line in reversed(text.split("\n")):
        m = re.match(r"^(?:Assistant|assistant):\s*(.+)$", line, re.IGNORECASE)
        if m:
            return m.group(1).strip()

    # Fallback: last non-empty paragraph (often the last message is assistant)
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    if paragraphs:
        return paragraphs[-1]

    return None


def trim_to_words(text: str, max_words: int) -> str:
    """Trim text to max_words, adding ellipsis if truncated."""
    words = text.split()
    if len(words) <= max_words:
        return text
    return " ".join(words[:max_words]) + "..."


def summarize_with_claude(
    last_message: str,
    custom_prompt: str = "",
) -> str | None:
    """Use headless Claude to generate a 1-sentence spoken summary (optional)."""
    if not last_message:
        return None

    last_message = trim_to_words(last_message.strip(), 500)
    if len(last_message) > 2000:
        last_message = last_message[:2000] + "..."

    base_instruction = (
        "You are the assistant who just wrote that message. Give a brief SPOKEN voice update to the user. "
        "Match the user's tone. Keep it to 1-2 sentences max. "
        "Since this will be spoken aloud, avoid file paths, UUIDs, hashes - use natural language."
        " What would you say?"
    )
    if custom_prompt:
        base_instruction += f"\n\nAdditional instruction: {custom_prompt}"

    prompt = f"YOUR LAST MESSAGE:\n{last_message}\n\n---\n{base_instruction}"

    try:
        result = subprocess.run(
            [
                "claude", "-p",
                "--output-format", "json",
                "--no-session-persistence",
                "--setting-sources", "",
                prompt,
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode == 0:
            data = json.loads(result.stdout)
            summary = data.get("result", "").strip()
            words = summary.split()
            if len(words) > 100:
                summary = " ".join(words[:100]) + "..."
            return summary
    except Exception:
        pass
    return None


def speak_summary(conversation_id: str, summary: str, voice: str) -> None:
    """Call the say script to speak the summary (runs in background)."""
    say_script = PLUGIN_ROOT / "scripts" / "say"
    if not say_script.exists():
        return
    try:
        subprocess.Popen(
            [
                str(say_script),
                "--session", conversation_id,
                "--voice", voice,
                summary,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        print("{}")
        return

    # Cursor stop hook input: conversation_id, transcript_path, status, loop_count, ...
    conversation_id = data.get("conversation_id", "")
    transcript_path_raw = data.get("transcript_path")

    enabled, voice, custom_prompt = get_voice_config()
    if not enabled:
        print("{}")
        return

    if not conversation_id:
        print("{}")
        return

    transcript_path = Path(transcript_path_raw) if transcript_path_raw else None
    last_message = None
    if transcript_path:
        last_message = get_last_assistant_from_transcript(transcript_path)

    if not last_message:
        print("{}")
        return

    summary = summarize_with_claude(last_message, custom_prompt)
    if not summary:
        summary = trim_to_words(last_message, 100)

    speak_summary(conversation_id, summary, voice)
    # Cursor stop hook: no followup_message so we don't auto-submit; empty output is fine
    print("{}")


if __name__ == "__main__":
    main()
