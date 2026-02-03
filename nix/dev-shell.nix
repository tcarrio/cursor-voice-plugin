# Dev shell for voice-plugin-cursor: pocket-tts and ffmpeg in PATH.
# pocket-tts is provided via uv (uvx) since it is not in nixpkgs.
pkgs:
let
  pocketTtsWrapper = pkgs.writeShellScript "pocket-tts" ''
    exec ${pkgs.uv}/bin/uvx pocket-tts "$@"
  '';
  devBin = pkgs.runCommand "voice-plugin-cursor-dev-bin" {} ''
    mkdir -p $out/bin
    ln -s ${pocketTtsWrapper} $out/bin/pocket-tts
  '';
in
pkgs.mkShell {
  name = "voice-plugin-cursor-dev";
  nativeBuildInputs = [
    pkgs.ffmpeg
    pkgs.uv
    devBin
  ];
}
