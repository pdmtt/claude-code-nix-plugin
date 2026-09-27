{
  runCommand,
  nixfmt,
  statix,
  deadnix,
  shellcheck,
  src,
}:
let
  mkLint =
    name: tool: script:
    runCommand "claude-code-nix-plugin-${name}" { nativeBuildInputs = [ tool ]; } ''
      cd ${src}
      ${script}
      touch $out
    '';
in
{
  format = mkLint "format" nixfmt ''
    find . -name '*.nix' -exec nixfmt --check {} +
  '';
  statix = mkLint "statix" statix ''
    statix check .
  '';
  deadnix = mkLint "deadnix" deadnix ''
    deadnix --fail .
  '';
  shellcheck = mkLint "shellcheck" shellcheck ''
    shellcheck scripts/*.sh
  '';
}
