{
  runCommand,
  jq,
  plugin,
}:
runCommand "claude-code-nix-plugin-tests" { nativeBuildInputs = [ jq ]; } ''
  # nix-instantiate wants a writable state dir, which the sandbox lacks
  export NIX_STATE_DIR=$TMPDIR/nix-state

  # resolve each hook through hooks.json, so the wiring is under test too
  hook() {
    jq -er --arg event "$1" --arg matcher "$2" \
      '.hooks[$event][] | select(.matcher == $matcher) | .hooks[0].command' \
      ${plugin}/hooks/hooks.json
  }
  postEdit=$(hook PostToolUse 'Edit|MultiEdit|Write')
  editGuard=$(hook PreToolUse 'Edit|MultiEdit|Write')
  bashGuard=$(hook PreToolUse Bash)

  failures=0
  # expect <exit code> <hook> <tool_input field> <value> <description> [stderr regex]
  # the regex keeps a blocking case from passing on an unrelated crash
  expect() {
    local rc=0
    jq -n --arg k "$3" --arg v "$4" '{tool_input: {($k): $v}}' | "$2" 2>stderr || rc=$?
    if [[ $rc == "$1" ]] && { [[ -z ''${6:-} ]] || grep -Eq -- "$6" stderr; }; then
      echo "ok: $5"
    else
      echo "FAIL: $5 (exit $rc, expected $1)"
      cat stderr
      failures=$((failures + 1))
    fi
  }

  printf '{ a=1;\nb   = 2; }\n' > unformatted.nix
  printf '{ a = 1\n' > broken.nix
  printf 'let unused = 1; in { }\n' > dead.nix
  printf '_: {\n  home.a = 1;\n  home.b = 2;\n  home.c = 3;\n}\n' > smelly.nix

  expect 0 "$postEdit" file_path "$PWD/unformatted.nix" "post-edit: valid file passes"
  expect 2 "$postEdit" file_path "$PWD/broken.nix" "post-edit: syntax error blocks" "syntax error"
  expect 2 "$postEdit" file_path "$PWD/dead.nix" "post-edit: deadnix finding blocks" "Unused let binding"
  expect 2 "$postEdit" file_path "$PWD/smelly.nix" "post-edit: statix finding blocks" "W:20:"
  expect 0 "$postEdit" file_path "$PWD/missing.nix" "post-edit: missing file is skipped"
  expect 0 "$postEdit" file_path /etc/hosts "post-edit: non-nix file is skipped"

  if [[ $(< unformatted.nix) != $'{\n  a = 1;\n  b = 2;\n}' ]]; then
    echo "FAIL: post-edit: file was not formatted"
    failures=$((failures + 1))
  fi

  expect 2 "$editGuard" file_path /repo/flake.lock "flake.lock edit blocks" "nix flake update"
  expect 0 "$editGuard" file_path /repo/flake.nix "flake.nix edit passes"

  expect 2 "$bashGuard" command "nix-env -iA nixpkgs.hello" "nix-env blocks" "imperatively"
  expect 2 "$bashGuard" command "cd x && nix profile install nixpkgs#jq" "chained nix profile blocks" "imperatively"
  expect 2 "$bashGuard" command "nix  profile list" "nix profile with extra spaces blocks" "imperatively"
  expect 0 "$bashGuard" command "nix shell nixpkgs#jq -c jq" "nix shell passes"
  expect 0 "$bashGuard" command "git log --grep=nix-environment" "nix-env as a substring passes"

  if [[ ! -x $(jq -r .nix.command ${plugin}/.lsp.json) ]]; then
    echo "FAIL: .lsp.json: nixd is not executable"
    failures=$((failures + 1))
  fi

  ((failures == 0)) && touch $out
''
