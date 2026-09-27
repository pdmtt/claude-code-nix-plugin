# claude-code-nix-plugin

A [Claude Code](https://code.claude.com) plugin for working on Nix code, built with Nix.
Every tool it runs is a pinned `/nix/store` path, so nothing needs to be on your `$PATH`.

## What it does

| Component                | When                               | Effect                                                                                                                        |
| ------------------------ | ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| nixd language server     | Claude works with a `.nix` file    | Diagnostics, definitions and references for Claude                                                                            |
| Post-edit check          | After Claude edits a `.nix` file   | Checks syntax (`nix-instantiate --parse`), formats (`nixfmt`), lints (`statix`, `deadnix`). Problems go back to Claude to fix |
| `flake.lock` guard       | Before Claude edits a file         | Blocks hand edits to `flake.lock`; points to `nix flake update` / `nix flake lock`                                            |
| Imperative-install guard | Before Claude runs a shell command | Blocks `nix-env` and `nix profile`; points to your declarative config or `nix shell` / `nix run`                              |

## Install

### Home Manager (standalone, or as a NixOS / nix-darwin module)

Add the flake as an input:

```nix
# flake.nix
inputs.claude-code-nix-plugin = {
  url = "github:pdmtt/claude-code-nix-plugin";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Pass `inputs` to your modules (for example through `extraSpecialArgs`), then:

```nix
programs.claude-code = {
  enable = true;
  plugins = [ inputs.claude-code-nix-plugin.packages.${pkgs.stdenv.hostPlatform.system}.default ];
};
```

### Without Home Manager

```bash
claude --plugin-dir "$(nix build --no-link --print-out-paths github:pdmtt/claude-code-nix-plugin)"
```

## Development

Useful commands:

```bash
nix fmt            # format the Nix files
nix flake check    # hook tests, formatting, statix, deadnix, shellcheck (what CI runs)
nix build          # build the plugin into ./result
claude --plugin-dir ./result   # test your local build with Claude Code
```

Repo structure:

```plaintext
.
├── scripts/            Contains the hook scripts written in plain shell.
├── package.nix         Uses writeShellApplication to wrap each script, pins required tools, and runs shellcheck during build.
└── tests.nix           Feeds sample inputs to the built hooks.json, then checks hook exit codes and messages.
```
