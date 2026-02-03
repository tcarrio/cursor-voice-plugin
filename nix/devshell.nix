# Default devshell for voice-plugin-cursor: pocket-tts and ffmpeg in PATH.
# Blueprint passes { pkgs, perSystem, ... } (per-system args).
{ pkgs, ... }: pkgs.mkShell {
  name = "voice-plugin-cursor-dev";
  nativeBuildInputs = [
    pkgs.ffmpeg
    pkgs.pocket-tts
  ];
}
