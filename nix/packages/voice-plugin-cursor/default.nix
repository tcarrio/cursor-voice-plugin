# Voice plugin package: wrapped Python/Bash scripts with pocket-tts, jq; optional ffmpeg.
# Override with .override { ffmpeg = pkgs.ffmpeg; pocketTts = pkgs.pocket-tts; } etc.
# .override { ffmpeg = null; } to exclude ffmpeg from runtime PATH.
{ pkgs, flake, system, ffmpeg ? pkgs.ffmpeg, pocketTts ? pkgs.pocket-tts, ... } @ args:

let
  pkgFun = { pkgs, flake, system, ffmpeg ? pkgs.ffmpeg, pocketTts ? pkgs.pocket-tts, ... }:
  let
    f = toString flake;
    # Scripts and hooks from the flake (only hooks/ and scripts/)
    scriptSrc = builtins.path {
      path = flake;
      name = "voice-plugin-cursor-scripts";
      filter = path: type:
        let
          p = toString path;
          b = baseNameOf path;
          under = p == f || pkgs.lib.hasPrefix (f + "/hooks") p || pkgs.lib.hasPrefix (f + "/scripts") p;
        in
        under
        && (type != "directory" || b != ".git")
        && b != "flake.nix"
        && b != "flake.lock";
    };

    # pocket-tts, ffmpeg (optional) on PATH for say script and stop hook
    runtimePath = pkgs.lib.makeBinPath (
      [
        pocketTts
        pkgs.curl
        pkgs.jq
      ]
      ++ (pkgs.lib.optional (ffmpeg != null) ffmpeg)
    );

    # Wrapper for scripts/say so pocket-tts, ffmpeg, curl are on PATH
    sayWrapper = pkgs.writeShellScript "say" ''
      export PATH="${runtimePath}:$PATH"
      exec "${scriptSrc}/scripts/say" "$@"
    '';

    # Merge-hooks script: takes one argument (hook JSON), merges into ~/.cursor/hooks.json
    mergeHooksScript = pkgs.writeShellScript "merge-cursor-voice-hooks" ''
      set -e
      HOOK_JSON="''${1:?Usage: merge-cursor-voice-hooks <hook-json>}"
      export PATH="${runtimePath}:$PATH"
      CURSOR_HOME="''${HOME}/.cursor"
      mkdir -p "$CURSOR_HOME"
      if [ ! -f "$CURSOR_HOME/hooks.json" ]; then
        echo "{\"version\":1,\"hooks\":{\"stop\":[$HOOK_JSON]}}" > "$CURSOR_HOME/hooks.json"
      else
        # Replace any existing stop_hook_cursor entry with ours so the store path is current
        jq --argjson hook "$HOOK_JSON" '
          .hooks.stop = ((.hooks.stop // []) | map(select(.command | contains("voice-plugin-cursor/hooks/stop_hook_cursor.py") | not)) + [$hook])
        ' "$CURSOR_HOME/hooks.json" > "$CURSOR_HOME/hooks.json.tmp"
        mv "$CURSOR_HOME/hooks.json.tmp" "$CURSOR_HOME/hooks.json"
      fi
    '';

  in
  pkgs.runCommand "voice-plugin-cursor-${pkgs.python3.version}" {
    meta = {
      description = "Cursor voice plugin - wrapped stop hook and say script with pocket-tts";
      mainProgram = "stop_hook_cursor";
    };
  } ''
    mkdir -p $out/bin
    mkdir -p $out/lib/voice-plugin-cursor/hooks
    mkdir -p $out/lib/voice-plugin-cursor/scripts

    cp "${scriptSrc}/hooks/stop_hook_cursor.py" $out/lib/voice-plugin-cursor/hooks/
    ln -s "${sayWrapper}" $out/lib/voice-plugin-cursor/scripts/say
    ln -s "${sayWrapper}" $out/bin/say

    # Stop hook runner: Python finds say at PLUGIN_ROOT/scripts/say; $out is expanded by the builder
    echo '#!${pkgs.runtimeShell}' > $out/bin/stop_hook_cursor
    echo 'export PATH="${runtimePath}:$PATH"' >> $out/bin/stop_hook_cursor
    echo "exec ${pkgs.python3}/bin/python $out/lib/voice-plugin-cursor/hooks/stop_hook_cursor.py \"\$@\"" >> $out/bin/stop_hook_cursor
    chmod +x $out/bin/stop_hook_cursor

    ln -s "${mergeHooksScript}" $out/bin/merge-cursor-voice-hooks
  '';
in
  pkgs.lib.makeOverridable pkgFun args