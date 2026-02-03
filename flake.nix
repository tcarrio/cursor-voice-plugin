{
  description = "Cursor IDE voice plugin — post-completion audible summaries (home-manager module)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }: 
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.default = import ./nix/dev-shell.nix pkgs;
    })
    // {
      homeManagerModules = {
        voice-plugin-cursor = import ./nix/voice-plugin-cursor.nix self;
        default = self.homeManagerModules.voice-plugin-cursor;
      };
    };
}
