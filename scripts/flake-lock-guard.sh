# shellcheck shell=bash
# PreToolUse: refuse hand edits to flake.lock.

file=$(jq -r '.tool_input.file_path // empty')
[[ ${file##*/} == flake.lock ]] || exit 0
echo "flake.lock is generated: change it with \`nix flake update\` or \`nix flake lock\`, not by hand" >&2
exit 2
