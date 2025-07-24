#!/usr/bin/env bash

source helpers/logger.bash

export_config_from_yaml() {
  for relpath in "$@"; do
    local basedir
    basedir=$(dirname "${BATS_TEST_FILENAME}")
    local file="${basedir}/${relpath}"

    if [[ ! -f "${file}" ]]; then
      log_warn "Config file not found: ${file}"
      continue
    fi

    [[ -n "$BATS_VERBOSE_CONFIG" ]] && echo "Reading from file: ${file}"
    [[ -n "$BATS_VERBOSE_CONFIG" ]] && cat "${file}"

    local tmpfile
    tmpfile=$(mktemp)
    yq e 'explode(.)' "${file}" > "${tmpfile}"

    while IFS= read -r path; do
      value=$(yq e ".${path}" "${tmpfile}")
      key_sanitized=$(echo "${path}" | tr '.' '_' | tr '[:lower:]' '[:upper:]')
      safe_value=$(printf "%q" "$value")
      echo "export CFG_${key_sanitized}=$safe_value"
      [[ -n "$BATS_VERBOSE_CONFIG" ]] && echo "CFG_${key_sanitized}=$value"
    done < <(yq e '.. | select(tag != "!!map" and tag != "!!seq") | path | join(".")' "${tmpfile}")

    rm -f "${tmpfile}"
  done
}

source_config_exports() {
  local file="$1"

  if [[ ! -f "${file}" ]]; then
    load_warn "Config file not found: ${file}"
    return 1
  fi

  local before after diff
  before=$(mktemp)
  after=$(mktemp)

  ( set -o posix ; set ) | sort > "${before}"

  # shellcheck source=/dev/null
  source "${file}"

  ( set -o posix ; set ) | sort > "${after}"

  diff=$(comm -13 "${before}" "${after}" | cut -d= -f1)

  for var in $diff; do
    printf 'export %s=%q\n' "$var" "${!var}"
  done

  rm -f "${before}" "${after}"
}

load_config() {
  local basedir file
  basedir=$(dirname "${BATS_TEST_FILENAME}")

  file="${basedir}/config.sh"
  if [[ -f "${file}" ]]; then
    source_config_exports "${file}"
    return
  fi

  file="${basedir}/config.yaml"
  if [[ -f "${file}" ]]; then
    export_config_from_yaml "config.yaml"
    return
  fi
}
