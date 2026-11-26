{
  description = "Render markdown files as slides in the terminal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nimver = {
      url = "github:vinpogo/nimver";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nimver,
    }:
    let
      inherit (nixpkgs) lib;

      forAllSystems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      maybeVersion = builtins.match ".*\n[[:space:]]*version[[:space:]]*=[[:space:]]*\"([^\"]+)\".*" (
        builtins.readFile ./nimslides.nimble
      );
      version =
        if maybeVersion == null then
          throw "flake.nix: no `version = \"...\"` line found in nimslides.nimble"
        else
          builtins.head maybeVersion;

      src = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [
          ./nimslides.nimble
          (lib.fileset.fileFilter (file: file.hasExt "nim") ./src)
        ];
      };

      nimslides =
        pkgs:
        pkgs.buildNimPackage (finalAttrs: {
          pname = "nimslides";
          inherit version src;
          lockFile = ./lock.json;

          nimDefines = [ "NimblePkgVersion=${finalAttrs.version}" ];
          nimFlags = [
            "--path:src"
            "--opt:speed"
          ];

          meta = {
            description = "Render markdown files as slides in the terminal";
            license = lib.licenses.gpl3Plus;
            mainProgram = "nimslides";
          };
        });
    in
    {
      packages = forAllSystems (
        system:
        let
          package = nimslides nixpkgs.legacyPackages.${system};
        in
        {
          nimslides = package;
          default = package;
        }
      );

      overlays.default = final: _: { nimslides = nimslides final; };

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # Regenerate lock.json with `nim_lk > lock.json` after changing
          # dependencies in nimslides.nimble. Patched until upstream parses
          # "v"-prefixed tags (it otherwise locks the wrong revision).
          nim_lk = pkgs.nim_lk.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./nix/nim_lk-v-tags.patch ];
          });
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nim
              pkgs.nimble
              pkgs.nph
              nim_lk
              nimver.packages.${system}.default
            ];
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      checks = forAllSystems (system: {
        nimslides = self.packages.${system}.nimslides;
      });
    };
}
