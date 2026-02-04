{
  description = "Cursor IDE voice plugin — post-completion audible summaries (home-manager module)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    blueprint.url = "github:numtide/blueprint";
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs:
    let
      bp = inputs.blueprint {
        inherit inputs;
        prefix = "nix/";
      };
      systems = import inputs.systems;
      lib = (import inputs.nixpkgs { system = builtins.head systems; }).lib;
      apps = lib.genAttrs systems (system:
        let
          pkgs = import inputs.nixpkgs { inherit system; };
          flake = inputs.self;
        in
        {
          test-python = {
            type = "app";
            program = "${pkgs.writeShellScript "test-python" ''
              set -e
              cd "${flake}"
              export PYTHONPATH="${flake}"
              exec ${pkgs.python3}/bin/python -m unittest discover -s tests -p 'test_*.py' -v
            ''}";
          };
        });
    in
    bp // {
      homeManagerModules.default = inputs.self.homeModules.voice-plugin-cursor;
      inherit apps;
    };
}