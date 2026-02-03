# Home Manager module: Cursor IDE voice plugin
# Injects commands/skills into ~/.cursor/* and the plugin into XDG_DATA_HOME;
# merges the stop hook into ~/.cursor/hooks.json.
self: { config, lib, pkgs, ... }:

let
  cfg = config.cursor.voicePlugin;

  # Plugin source in store (exclude flake metadata and .git)
  pluginSrc = builtins.path {
    path = self;
    name = "voice-plugin-cursor";
    filter = path: type:
      let b = baseNameOf path;
      in (type != "directory" || b != ".git")
         && b != "flake.nix"
         && b != "flake.lock";
  };

  hookEntry = {
    command = "python3 ${pluginSrc}/hooks/stop_hook_cursor.py";
    timeout = 60;
  };
  hookJson = builtins.toJSON hookEntry;

  mergeHooksScript = pkgs.writeShellScript "merge-cursor-voice-hooks" ''
    set -e
    HOOK_JSON=${lib.escapeShellArg hookJson}
    CURSOR_HOME="''${HOME}/.cursor"
    mkdir -p "$CURSOR_HOME"
    if [ ! -f "$CURSOR_HOME/hooks.json" ]; then
      echo "{\"version\":1,\"hooks\":{\"stop\":[$HOOK_JSON]}}" > "$CURSOR_HOME/hooks.json"
    else
      if ${pkgs.jq}/bin/jq -e '.hooks.stop[]? | select(.command | contains("stop_hook_cursor"))' "$CURSOR_HOME/hooks.json" >/dev/null 2>&1; then
        :
      else
        ${pkgs.jq}/bin/jq --argjson hook "$HOOK_JSON" '.hooks.stop += [$hook]' "$CURSOR_HOME/hooks.json" > "$CURSOR_HOME/hooks.json.tmp"
        mv "$CURSOR_HOME/hooks.json.tmp" "$CURSOR_HOME/hooks.json"
      fi
    fi
  '';
in
{
  options.cursor.voicePlugin = {
    enable = lib.mkEnableOption "Cursor IDE voice plugin (commands, skills, stop hook, plugin in XDG_DATA_HOME)";

    ffmpeg = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install ffmpeg";
    };
  };

  config = lib.mkIf cfg.enable {
    # Plugin tree in XDG_DATA_HOME (same layout as install-cursor.sh)
    xdg.dataFile."voice-plugin-cursor".source = pluginSrc;

    # Cursor-required: commands and skills under ~/.cursor (Cursor does not use XDG for these)
    home.file.".cursor/commands/speak.md".source = "${pluginSrc}/.cursor/commands/speak.md";
    home.file.".cursor/skills/voice-update/SKILL.md".source = "${pluginSrc}/.cursor/skills/voice-update/SKILL.md";

    # Merge stop hook into ~/.cursor/hooks.json (Cursor reads from ~/.cursor, not XDG config)
    home.activation.mergeCursorVoiceHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${mergeHooksScript}
    '';

    home.packages = [
      pkgs.pocket-tts
    ] ++ (lib.optionals cfg.ffmpeg [
      pkgs.ffmpeg
    ]);
  };
}
