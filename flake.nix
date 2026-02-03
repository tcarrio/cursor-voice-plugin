{
  description = "Cursor IDE voice plugin — post-completion audible summaries (home-manager module)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, ... } @ inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.home-manager.flakeModules.home-manager
      ];

      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { system, ... }: {
        devShells.default = import ./nix/dev-shell.nix inputs.nixpkgs.legacyPackages.${system};
      };

      flake.homeManagerModules.default = self.homeManagerModules.voice-plugin-cursor;
    };
}
