# shellcheck shell=bash
# PreToolUse: refuse `nix-env` and `nix profile`, which mutate the profile
# imperatively. A guardrail against habit, not a sandbox: `sh -c`, aliases or
# variables slip past it.

cmd=$(jq -r '.tool_input.command // empty')
b='[^[:alnum:]_-]'
re="(^|$b)(nix-env|nix[[:space:]]+profile)($b|$)"
[[ $cmd =~ $re ]] || exit 0
echo "\`nix-env\` and \`nix profile\` mutate the profile imperatively: declare packages in the Home Manager or NixOS config, or use \`nix shell\`/\`nix run\` for one-offs" >&2
exit 2
