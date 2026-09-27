{
  description = "Claude Code plugin for Nix: nixd, plus format, lint and guardrail hooks";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
    in
    {
      packages = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.callPackage ./package.nix { };
      });

      checks = forAllSystems (system: {
        hooks = nixpkgs.legacyPackages.${system}.callPackage ./tests.nix {
          plugin = self.packages.${system}.default;
        };
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
