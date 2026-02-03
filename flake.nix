{
  description = "Cursor IDE voice plugin — post-completion audible summaries (home-manager module)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    blueprint.url = "github:numtide/blueprint";
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs: inputs.blueprint {
    inherit inputs;
    prefix = "nix/";
  } // {
    homeManagerModules.default = inputs.self.homeModules.voice-plugin-cursor;
  };
}