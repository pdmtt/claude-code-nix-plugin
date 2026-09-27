{
  lib,
  runCommand,
  writers,
  nixd,
}:
let
  manifest = writers.writeJSON "plugin.json" {
    name = "nix";
    version = "0.1.0";
    description = "nixd, plus format, lint and guardrail hooks for Nix";
    author.name = "Pedro Roque de Mattia";
    license = "MIT";
  };

  lsp = writers.writeJSON "lsp.json" {
    nix = {
      command = lib.getExe nixd;
      extensionToLanguage.".nix" = "nix";
    };
  };
in
runCommand "claude-code-nix-plugin"
  {
    meta = {
      description = "Claude Code plugin for Nix: nixd, plus format, lint and guardrail hooks";
      license = lib.licenses.mit;
      platforms = lib.platforms.unix;
    };
  }
  ''
    install -Dm644 ${manifest} $out/.claude-plugin/plugin.json
    install -Dm644 ${lsp} $out/.lsp.json
  ''
