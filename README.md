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

> [!WARNING]
> The imperative-install guard matches the command text, not what the command does.
> It blocks harmless mentions too, such as `git commit -m "remove nix-env usage"`,
> and it misses workarounds like `sh -c "$cmd"` or aliases.
>
> Treat it as a nudge against habit, not a security boundary.
>
> To turn it off, see [Disable the imperative-install guard](#disable-the-imperative-install-guard).

## Install

> [!IMPORTANT]
> If you already set up nixd language server yourself, remove it: this plugin provides it.

Requirements:

- Nix with flakes enabled
- Claude Code
- One of the supported system architectures: `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`

### Home Manager

Add the flake as an input and pass `inputs` on to your Home Manager modules:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code-nix-plugin = {
      url = "github:pdmtt/claude-code-nix-plugin/v0";
      # The following line builds the plugin with your nixpkgs, so nixd, nixfmt, statix and deadnix are the versions your nixpkgs has.
      # Drop it to use the versions from this flake's lock file instead.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # `inputs@` names the whole attribute set, so it can be passed on below
  outputs =
    inputs@{ nixpkgs, home-manager, ... }:
    {
      homeConfigurations."<user>" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          # claude-code is unfree in nixpkgs, so allow it
          config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "claude-code" ];
        };
        # If Home Manager runs as a NixOS or nix-darwin module,
        # pass with `home-manager.extraSpecialArgs = { inherit inputs; };` in your configuration instead of `extraSpecialArgs`.
        extraSpecialArgs = { inherit inputs; };
        modules = [ ./home.nix ];
      };
    };
}
```

Then, in a Home Manager module:

```nix
# home.nix
{ inputs, pkgs, ... }:
{
  programs.claude-code = {
    enable = true;
    plugins = [ inputs.claude-code-nix-plugin.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  };
}
```

Finally, apply it with `home-manager switch` (or `nixos-rebuild switch` / `darwin-rebuild switch`),
then restart Claude Code.

### Without Home Manager

```bash
nix build --out-link ~/.local/state/claude-code-nix-plugin github:pdmtt/claude-code-nix-plugin/v0
claude --plugin-dir ~/.local/state/claude-code-nix-plugin
```

Rerun `nix build` whenever you want to update.

> [!NOTE]
> The out-link keeps `nix-collect-garbage` from deleting the plugin, and gives it a fixed path you can
> put in a shell alias.

### Check that it works

- `/plugin` inside Claude Code lists the `nix` plugin
- Ask Claude to edit a `.nix` file: the file comes back formatted by `nixfmt`

> [!NOTE]
> The first time Claude edits an existing file, statix and deadnix report any warnings already in it,
> and Claude fixes them as part of the edit.

> [!TIP]
> To silence a statix rule you don't follow, list it in a
> [`statix.toml`](https://github.com/oppiliappan/statix#configuration) at the repo root.

## Configuration

### Pin a release

`github:pdmtt/claude-code-nix-plugin/v0` pins a release tag: `nix flake update` leaves it alone,
and you move to a new release by changing the tag.

Without a tag, `github:pdmtt/claude-code-nix-plugin` follows the `main` branch, and `nix flake update` pulls whatever is
on it.

### Disable the imperative-install guard

The package takes an `enableImperativeNixGuard` argument, `true` by default:

```nix
plugins = [
  (inputs.claude-code-nix-plugin.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
    enableImperativeNixGuard = false;
  })
];
```

The other hooks and nixd stay on.

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
