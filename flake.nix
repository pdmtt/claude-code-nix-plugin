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

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          hooks = pkgs.callPackage ./tests.nix { plugin = self.packages.${system}.default; };

          without-imperative-nix-guard =
            let
              plugin = self.packages.${system}.default.override { enableImperativeNixGuard = false; };
            in
            pkgs.runCommand "claude-code-nix-plugin-without-guard" { nativeBuildInputs = [ pkgs.jq ]; } ''
              jq -e '.hooks | (.PreToolUse | map(.matcher)) == ["Edit|MultiEdit|Write"]
                and (.PostToolUse | length) == 1' ${plugin}/hooks/hooks.json
              touch $out
            '';
        }
        // pkgs.callPackages ./lint.nix { src = self; }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
