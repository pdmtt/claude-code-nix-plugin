# shellcheck shell=bash
# PostToolUse: after an edit to a .nix file, check its syntax, format it and
# lint it. One script rather than one hook per tool: hooks sharing a matcher
# run in parallel, and the linters must see nixfmt's output.

file=$(jq -r '.tool_input.file_path // empty')
[[ $file == *.nix && -f $file ]] || exit 0

if ! err=$(nix-instantiate --parse "$file" 2>&1 >/dev/null); then
  echo "$err" >&2
  exit 2
fi

nixfmt "$file"

status=0
statix check --format errfmt "$file" >&2 || status=2
# the default report is ANSI-drawn source excerpts; flatten it to statix's
# one-line errfmt; pipefail keeps deadnix's exit status
deadnix --fail --output-format json "$file" |
  jq -r '.file as $f | .results[] | "\($f)>\(.line):\(.column):W:\(.message)"' >&2 ||
  status=2
exit "$status"
