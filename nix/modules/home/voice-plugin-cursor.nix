# Home Manager module: Cursor IDE voice plugin
# Injects commands/skills into ~/.cursor/* and the plugin into XDG_DATA_HOME;
# merges the stop hook into ~/.cursor/hooks.json.
#
# Scripts (stop hook, say, merge-hooks) come from the flake's voice-plugin-cursor
# package, which wraps pocket-tts, ffmpeg, jq so the consumer's pkgs need not have them.
#
# Blueprint passes { flake, inputs } (publisherArgs). config/lib/pkgs come from
# Home Manager when a consumer imports this module.
{ flake, ... }: { config, lib, pkgs, ... }:

let
  cfg = config.cursor.voicePlugin;
  system = pkgs.stdenv.hostPlatform.system;
  # Pass module options into the package override so scripts use the chosen pocket-tts/ffmpeg
  voicePluginPkg = (flake.packages.${system}.voice-plugin-cursor).override {
    pocketTts = cfg.pocketTts.package;
    ffmpeg = if cfg.ffmpeg.enable then cfg.ffmpeg.package else null;
  };

  # Plugin source in store for XDG_DATA_HOME and .cursor (commands/skills)
  pluginSrc = builtins.path {
    path = flake;
    name = "voice-plugin-cursor";
    filter = path: type:
      let b = baseNameOf path;
      in (type != "directory" || b != ".git")
         && b != "flake.nix"
         && b != "flake.lock";
  };

  hookEntry = {
    command = "${voicePluginPkg}/bin/stop_hook_cursor";
    timeout = 60;
  };
  hookJson = builtins.toJSON hookEntry;
in
{
  options.cursor.voicePlugin = {
    enable = lib.mkEnableOption "Cursor IDE voice plugin (commands, skills, stop hook, plugin in XDG_DATA_HOME)";

    pocketTts = {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.pocket-tts;
        defaultText = lib.literalExpression "pkgs.pocket-tts";
        description = "pocket-tts package used by the say script and stop hook (in runtime PATH)";
      };
    };

    ffmpeg = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Add ffmpeg to the plugin package runtime PATH (for say script streaming playback)";
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.ffmpeg;
        defaultText = lib.literalExpression "pkgs.ffmpeg";
        description = "The ffmpeg package to use when ffmpeg.enable is true";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Plugin tree in XDG_DATA_HOME (same layout as install-cursor.sh)
    xdg.dataFile."voice-plugin-cursor".source = pluginSrc;

    # Cursor-required: commands and skills under ~/.cursor (Cursor does not use XDG for these)
    home.file.".cursor/commands/speak.md".source = "${pluginSrc}/.cursor/commands/speak.md";
    home.file.".cursor/skills/voice-update/SKILL.md".source = "${pluginSrc}/.cursor/skills/voice-update/SKILL.md";

    # Merge stop hook into ~/.cursor/hooks.json using the package's script (has jq)
    home.activation.mergeCursorVoiceHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${voicePluginPkg}/bin/merge-cursor-voice-hooks ${lib.escapeShellArg hookJson}
    '';

    home.packages = [ voicePluginPkg ];
  };
}
