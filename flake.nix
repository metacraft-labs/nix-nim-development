{
  description = "langserver";

  inputs = {
    nixos-modules.url = "github:metacraft-labs/nixos-modules";

    nixpkgs.follows = "nixos-modules/nixpkgs";
    flake-parts.follows = "nixos-modules/flake-parts";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixos-modules,
    flake-parts,
    rust-overlay,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      imports = [
        nixos-modules.modules.flake.git-hooks
      ];

      flake = {
        mcl.shard-matrix.systemsToBuild = [
          "x86_64-linux"
          "aarch64-darwin"
        ];

        overlays.default =
          nixpkgs.lib.fixedPoints.composeExtensions
          rust-overlay.overlays.default
          (import ./overlay.nix);
      };

      perSystem = {
        pkgs,
        system,
        ...
      }: let
        overlayedPkgs = import nixpkgs {
          inherit system;
          overlays = [
            self.overlays.default
          ];
        };
      in {
        packages = overlayedPkgs.metacraft-labs;
        devShells.default = import ./shell.nix {pkgs = overlayedPkgs;};
      };
    };
}
