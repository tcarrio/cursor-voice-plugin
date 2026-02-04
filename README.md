# Voice Plugin (Cursor IDE)

Post-completion audible summaries for the Cursor agent using [pocket-tts](https://github.com/kyutai-labs/pocket-tts).

When the agent finishes a task, you get a short spoken summary of what was done. All configuration is **global** (home directory only); a single shared `pocket-tts serve` instance is used across Cursor and any CLI usage.

## Requirements

- **TTS server**: Either a globally installed [pocket-tts](https://github.com/kyutai-labs/pocket-tts) (`pocket-tts` in PATH), or [uv](https://docs.astral.sh/uv/) so the script can run `uvx pocket-tts serve` as fallback
- **macOS**: `afplay` (built-in)  
- **Linux**: `aplay` or `paplay`
- **Recommended**: [FFmpeg](https://ffmpeg.org/) (`ffplay`) for lower-latency streaming

## Installation (global)

Install once per machine. Voice plugin artifacts use [XDG Base Directory](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html); only Cursor-required files live under `~/.cursor/`.

```bash
git clone https://github.com/YOUR_FORK/voice-plugin-cursor.git
cd voice-plugin-cursor
./install-cursor.sh
```

This will:

- Copy the plugin to **`$XDG_DATA_HOME/voice-plugin-cursor/`** (default `~/.local/share/voice-plugin-cursor/`)
- Add or merge the **stop** hook in **`~/.cursor/hooks.json`** (Cursor requires this path)
- Install the `/speak` command and **voice-update** skill into **`~/.cursor/commands/`** and **`~/.cursor/skills/`** (Cursor requires these)
- Create voice config on first use under **`$XDG_CONFIG_HOME/voice-plugin-cursor/voice.local.md`** (default `~/.config/voice-plugin-cursor/`)

Restart Cursor so hooks and commands load.

### Installation via Nix (home-manager)

The repo is a **Nix flake** (using [Blueprint](https://github.com/numtide/blueprint) with `prefix = "nix/"`) that provides a **home-manager module** so you can enable the voice plugin declaratively. All Nix config lives under `nix/` (e.g. `nix/devshell.nix`, `nix/modules/home/`). The module injects commands and skills into `~/.cursor/*`, installs the plugin into `$XDG_DATA_HOME/voice-plugin-cursor`, and merges the stop hook into `~/.cursor/hooks.json`.

**Add the flake and enable the module:**

```nix
# In your flake inputs (e.g. flake.nix)
inputs.voice-plugin-cursor.url = "github:YOUR_USER/voice-plugin-cursor";  # or path:/path/to/voice-plugin-cursor

# In your home-manager configuration (e.g. in a module or home.nix)
{ config, inputs, ... }: {
  imports = [ inputs.voice-plugin-cursor.homeManagerModules.default ];

  cursor.voicePlugin.enable = true;
}
```

Then rebuild your home-manager config (e.g. `home-manager switch --flake .`). No need to run `install-cursor.sh`; the module manages the same layout in a Nix-native way (store paths linked into `~/.local/share/voice-plugin-cursor` and `~/.cursor/commands` / `~/.cursor/skills`, and hooks.json merged at activation).

## Where things live

| Location | Purpose |
|----------|--------|
| **XDG (voice plugin only)** | |
| `$XDG_DATA_HOME/voice-plugin-cursor/` | Plugin files (hooks, `scripts/say`). Default: `~/.local/share/voice-plugin-cursor/` |
| `$XDG_CONFIG_HOME/voice-plugin-cursor/voice.local.md` | Voice on/off, voice name, custom prompt. Default: `~/.config/voice-plugin-cursor/` |
| `$XDG_STATE_HOME/voice-plugin-cursor/` | TTS server log, PID, runtime. Default: `~/.local/state/voice-plugin-cursor/` |
| **~/.cursor/ (required by Cursor)** | |
| `~/.cursor/hooks.json` | Cursor hooks (stop hook points at plugin in XDG_DATA_HOME) |
| `~/.cursor/commands/` | `/speak` command |
| `~/.cursor/skills/` | voice-update skill |

No project-local config; the same voice settings apply everywhere.

## Shared pocket-tts server

One TTS server is used for all Cursor sessions and for the `say` script:

- **Default**: The `say` script will auto-start the TTS server on first use (host `localhost`, port `8000`). It prefers a globally installed **`pocket-tts`** (if in PATH); otherwise uses **`uvx pocket-tts serve`**. Log and PID file follow [XDG Base Directory](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html): state under `$XDG_STATE_HOME/voice-plugin-cursor/` (default `~/.local/state/voice-plugin-cursor/`).
- **Run your own**: Start the server yourself (e.g. in a terminal or as a user service), then either:
  - Use the default host/port so `say` and the hook just connect, or
  - Set `TTS_HOST` / `TTS_PORT` so they point at your instance.
- **No auto-start**: Set `TTS_SKIP_AUTO_START=1` in your environment. Then `say` only connects to an already-running server and will error if it’s not up.

Environment variables (optional):

- `TTS_HOST` – server host (default: `localhost`)
- `TTS_PORT` – server port (default: `8000`)
- `TTS_SKIP_AUTO_START` – if set, never start the server; only connect to existing
- `TTS_LOG` – log file when the script auto-starts the server (default: `$XDG_STATE_HOME/voice-plugin-cursor/pocket-tts.log`)
- `XDG_STATE_HOME` – base dir for state (default: `~/.local/state`). Server log and **server PID file** (`pocket-tts.pid`) live in `…/voice-plugin-cursor/`.
- `XDG_RUNTIME_DIR` – base dir for session runtime (optional). When set, playback lock and session-flag files use `…/voice-plugin-cursor/`; otherwise they use `$XDG_STATE_HOME/voice-plugin-cursor/run/`.
- `XDG_CONFIG_HOME` – base dir for config (default: `~/.config`). Voice config is `…/voice-plugin-cursor/voice.local.md`.
- `XDG_DATA_HOME` – base dir for data (default: `~/.local/share`). Plugin is installed under `…/voice-plugin-cursor/`.

## How it works

### Stop hook

On agent stop, the hook:

1. Reads voice config from `$XDG_CONFIG_HOME/voice-plugin-cursor/voice.local.md`
2. If enabled, reads the last assistant turn from Cursor’s transcript (when `transcript_path` is provided)
3. Optionally uses headless Claude to shorten it into a spoken summary
4. Calls `say` to speak the summary (using the shared TTS server)
5. Returns without blocking (no follow-up message)

### `/speak` command

- `/speak` – Enable voice feedback
- `/speak <voice>` – Set voice (e.g. azure, alba) and enable
- `/speak stop` – Disable voice feedback
- `/speak prompt <text>` – Custom instruction for summaries
- `/speak prompt` – Clear custom prompt

Config is written to `$XDG_CONFIG_HOME/voice-plugin-cursor/voice.local.md`.

### Configuring voice

These are the available voices as of this commit:

- `alba`
- `marius`
- `javert`
- `jean`
- `fantine`
- `cosette`
- `eponine` *
- `azelma`

The default is `eponine`. You can run the `/speak <voice>` command to update this setting.


### Custom prompts

Examples:

- `/speak prompt "be upbeat and encouraging"`
- `/speak prompt "use 5 words or less"`
- `/speak prompt "always end with 'back to you, boss'"`

### The `say` script

Used by the stop hook; you can also call it from the shell or from the agent (e.g. via the voice-update skill):

```bash
~/.local/share/voice-plugin-cursor/scripts/say "Hello, world!"
~/.local/share/voice-plugin-cursor/scripts/say --voice azure "Done with the refactor."
```

It uses the same config and shared server as above.

## Disabling

- In Cursor: `/speak stop` (disables voice; config stays in XDG config).
- To remove the plugin: delete `$XDG_DATA_HOME/voice-plugin-cursor/` and remove the stop hook entry from `~/.cursor/hooks.json`.

## Troubleshooting

- **Server won’t start**  
  Check the log (default `$XDG_STATE_HOME/voice-plugin-cursor/pocket-tts.log` or `~/.local/state/voice-plugin-cursor/pocket-tts.log`). Server PID is in `…/voice-plugin-cursor/pocket-tts.pid`. If you use `TTS_SKIP_AUTO_START=1`, start the server manually:  
  `pocket-tts serve --host localhost --port 8000` (or `uvx pocket-tts serve ...` if not installed globally)

- **No audio**  
  macOS: `afplay` should be present. Linux: install `alsa-utils` (aplay) or ensure PulseAudio (paplay) is available.

- **Slow first playback**  
  Install FFmpeg (`ffplay`) for streaming; the script will use it when available.

---

This repo is a fork of the voice plugin from the **claude-code-tools** project, adapted for Cursor (hooks, commands, skills) with global-only config and a single shared pocket-tts server.
