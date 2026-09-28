{
  lib,
  runCommand,
  writers,
  writeShellApplication,
  jq,
  nix,
  nixfmt,
  statix,
  deadnix,
  nixd,
  # matches command text, so it also blocks harmless mentions of the commands
  enableImperativeNixGuard ? true,
}:
let
  # hooks read the tool call as JSON on stdin; exit 2 hands stderr back to
  # Claude -- blocking the call on Pre*, prompting a fix on Post*
  mkHook =
    name: runtimeInputs:
    lib.getExe (writeShellApplication {
      inherit name;
      runtimeInputs = [ jq ] ++ runtimeInputs;
      text = builtins.readFile (./scripts + "/${name}.sh");
    });

  mkMatcher = matcher: commands: {
    inherit matcher;
    hooks = map (command: {
      type = "command";
      inherit command;
    }) commands;
  };

  fileEdits = "Edit|MultiEdit|Write";

  manifest = writers.writeJSON "plugin.json" {
    name = "nix";
    version = "0.1.0";
    description = "nixd, plus format, lint and guardrail hooks for Nix";
    author.name = "Pedro Roque de Mattia";
    license = "MIT";
  };

  hooks = writers.writeJSON "hooks.json" {
    hooks = {
      PreToolUse = [
        (mkMatcher fileEdits [ (mkHook "flake-lock-guard" [ ]) ])
      ]
      ++ lib.optional enableImperativeNixGuard (mkMatcher "Bash" [ (mkHook "imperative-nix-guard" [ ]) ]);
      PostToolUse = [
        (mkMatcher fileEdits [
          (mkHook "nix-post-edit" [
            nix
            nixfmt
            statix
            deadnix
          ])
        ])
      ];
    };
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
    install -Dm644 ${hooks} $out/hooks/hooks.json
    install -Dm644 ${lsp} $out/.lsp.json
  ''
