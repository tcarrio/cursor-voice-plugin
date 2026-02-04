# Agent context: voice-plugin-cursor

Short reference for humans and AI agents working in this repo.

## Project

Cursor IDE voice plugin: post-completion spoken summaries via pocket-tts. Provides a **home-manager module** and a **Nix package** (wrapped stop hook + say script with pocket-tts/ffmpeg/jq). Non-Nix install via `install-cursor.sh`. See [README.md](README.md) for user-facing docs.

## Nix layout

- **Blueprint** flake with `prefix = "nix/"`. Config lives under `nix/`.
- **Packages**: `nix/packages/voice-plugin-cursor/default.nix` → flake output `packages.<system>.voice-plugin-cursor`.
- **Home Manager module**: `nix/modules/home/voice-plugin-cursor.nix` → `homeModules.voice-plugin-cursor` (Blueprint) and re-exported as `homeManagerModules.default`.
- **Dev shell**: `nix/devshell.nix` → `devShells.<system>.default` (pocket-tts, ffmpeg in PATH).

## Useful commands

Run from repo root.

| Goal | Command |
|------|--------|
| Test that the home-manager module evaluates | `nix eval .#homeManagerModules.default` |
| Same (if using blueprint’s homeModules directly) | `nix eval .#homeModules.voice-plugin-cursor` |
| Build the voice-plugin-cursor package | `nix build .#packages.$(nix eval --raw .#currentSystem).voice-plugin-cursor` or `nix build .#voice-plugin-cursor` if your flake exposes that app/package name |
| Enter dev shell (pocket-tts, ffmpeg, etc. in PATH) | `nix develop` |
| Run test suite (Python unittest) as part of flake checks | `nix flake check` |
| Run Python tests via flake app (task-like) | `nix run '.#test-python'` |
| See unittest output when building the test check | `nix build '.#checks.<system>.pkgs-voice-plugin-cursor-voice-plugin-cursor-tests' --print-build-logs`; or after building, `cat result/test-output.log` |
| Force rebuild so test output is shown (if last run was cached) | Same as above but add `--rebuild`: `nix build '.#checks.<system>.pkgs-voice-plugin-cursor-voice-plugin-cursor-tests' --rebuild --print-build-logs` |
| List flake outputs (see exact attribute names) | `nix flake show` |

Consumers use the module by importing `inputs.voice-plugin-cursor.homeManagerModules.default` and setting `cursor.voicePlugin.enable = true`; then `home-manager switch --flake .` (or their usual home-manager command).

## Home-manager module options

Under `config.cursor.voicePlugin`:

- **`enable`** (bool): Enable the plugin (commands, skills, stop hook, XDG_DATA_HOME plugin).
- **`pocketTts.package`** (package): pocket-tts derivation for the script/hook PATH. Default: `pkgs.pocket-tts`.
- **`ffmpeg.enable`** (bool): Add ffmpeg to the plugin’s runtime PATH. Default: `true`.
- **`ffmpeg.package`** (package): ffmpeg derivation when `ffmpeg.enable` is true. Default: `pkgs.ffmpeg`.

The module passes these into the package via `.override { pocketTts = ...; ffmpeg = ...; }`.

## Package overrides

`nix/packages/voice-plugin-cursor/default.nix` is overridable:

- **`pocketTts`** (default: `pkgs.pocket-tts`): package placed on runtime PATH for the say script and stop hook.
- **`ffmpeg`** (default: `pkgs.ffmpeg`, or `null` to omit): optional; when non-null, ffmpeg is added to runtime PATH for streaming playback.

Example: `(flake.packages.${system}.voice-plugin-cursor).override { ffmpeg = null; }` to build without ffmpeg on PATH.

## Key paths

| Path | Purpose |
|------|--------|
| `flake.nix` | Flake entry; Blueprint + `homeManagerModules.default` |
| `nix/modules/home/voice-plugin-cursor.nix` | Home Manager module and `cursor.voicePlugin` options |
| `nix/packages/voice-plugin-cursor/default.nix` | Package: wrapped `stop_hook_cursor`, `say`, `merge-cursor-voice-hooks` |
| `nix/devshell.nix` | Dev shell definition |
| `hooks/stop_hook_cursor.py` | Stop hook script (Python) |
| `scripts/say` | TTS CLI script (Bash) |
| `.cursor/commands/speak.md`, `.cursor/skills/voice-update/SKILL.md` | Cursor command and skill (copied into `~/.cursor/`) |
