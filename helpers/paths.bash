#!/usr/bin/env bash

## _resolve_path
#
# Resolves a given path to an absolute path.
# If the path is already absolute, it returns it as is.
# Otherwise, it treats the path as relative to the directory of the currently
# executing Bats test file and constructs an absolute path.
#
# @param $1 The path to resolve. Can be absolute or relative.
# @env BATS_TEST_FILENAME The path to the currently executing Bats test file.
# @stdout The resolved absolute path.
_resolve_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    echo "$path"
  else
    local basedir
    basedir=$(dirname "$BATS_TEST_FILENAME")
    echo "$basedir/$path"
  fi
}
