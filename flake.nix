{
  description = "langserver";

  inputs = {
    nixos-modules.url = "github:metacraft-labs/devops-modules";

    nixpkgs.follows = "nixos-modules/nixpkgs";
    flake-parts.follows = "nixos-modules/flake-parts";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixos-modules,
      flake-parts,
      rust-overlay,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
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

        overlays.default = nixpkgs.lib.fixedPoints.composeExtensions rust-overlay.overlays.default (
          import ./overlay.nix
        );
      };

      perSystem =
        {
          pkgs,
          system,
          config,
          ...
        }:
        let
          overlayedPkgs = import nixpkgs {
            inherit system;
            overlays = [
              self.overlays.default
            ];
          };
        in
        {
          packages = overlayedPkgs.metacraft-labs;
          # CI evaluates checks; retain every actual exported package derivation.
          checks =
            config.packages
            //
              builtins.mapAttrs
                (
                  _: check:
                  check.overrideAttrs (old: {
                    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.python3 ];
                    # Archive only after every real assertion has passed. Keep this
                    # policy shared by all retained compiler-evidence checks.
                    buildCommand = old.buildCommand + ''
                      python3 ${./tests}/normalize_check_artifacts.py "$out"
                    '';
                  })
                )
                {
                  nim-ownership = overlayedPkgs.callPackage ./packages/nim/check.nix {
                    inherit (overlayedPkgs.metacraft-labs) nim nim-unwrapped;
                    baseline = pkgs.nim2;
                  };
                  nim-symbol-owner = overlayedPkgs.callPackage ./packages/nim/check-symbol-owner.nix {
                    inherit (overlayedPkgs.metacraft-labs) nim nim-unwrapped;
                    baseline = pkgs.nim2;
                  };
                  nim-artifact-retention =
                    pkgs.runCommand "nim-artifact-retention-check"
                      {
                        nativeBuildInputs = [
                          pkgs.stdenv.cc
                          pkgs.python3
                        ];
                      }
                      ''
                        export HOME="$TMPDIR" PYTHONDONTWRITEBYTECODE=1
                        mkdir -p "$out"
                        python3 ${./tests}/test_artifact_retention.py \
                          --nim ${overlayedPkgs.metacraft-labs.nim-unwrapped}/bin/nim \
                          --output "$out" > "$out/tests.log" 2>&1 || {
                            cat "$out/tests.log"
                            exit 1
                          }
                        cat "$out/tests.log"
                      '';
                };

          devShells.default = import ./shell.nix { pkgs = overlayedPkgs; };
        };
    };
}
