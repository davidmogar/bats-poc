#!/usr/bin/env bash

: "${VERBOSE:=false}"
: "${LOG_STYLE:=none}"  # Options: none, emoji, level
: "${DEBUG:=false}"

if [[ "$DEBUG" == "true" ]]; then
  VERBOSE=true
fi

## _logger_output
#
# Internal helper function to output log messages.
# It prepends a "# " prefix to the message. If `VERBOSE` is true and file descriptor 3
# is open, it writes to stdout (fd 3); otherwise, it writes to stderr (fd 2).
# If `VERBOSE` is false, it always writes to stderr.
#
# @param $1 The message to be logged.
# @env VERBOSE If "true", outputs to stdout (fd 3) if available, otherwise to stderr. If "false", always outputs to stderr.
_logger_output() {
  local msg="$1"
  local prefix="# "

  if [[ "$VERBOSE" == "true" ]]; then
    if { true >&3; } 2>/dev/null; then
      echo "${prefix}${msg}" >&3
    else
      echo "${prefix}${msg}" >&2
    fi
  else
    echo "${prefix}${msg}" >&2
  fi
}

## log_debug
#
# Logs a debug message. Messages are only output if the `DEBUG` environment variable is "true".
# The output format also depends on the `LOG_STYLE` environment variable.
#
# @param $@ The message to log.
# @env DEBUG If "true", debug messages are output.
# @env LOG_STYLE Options: `none` (default, just message), `emoji` (prepends 🐛), `level` (prepends [DEBUG]).
log_debug() {
  if [[ "$DEBUG" == "true" ]]; then
    case "$LOG_STYLE" in
      emoji) _logger_output "🐛  $*" ;;
      level) _logger_output "[DEBUG] $*" ;;
      *)     _logger_output "$*" ;;
    esac
  fi
}

## log_error
#
# Logs an error message. The output format depends on the `LOG_STYLE` environment variable.
#
# @param $@ The message to log.
# @env LOG_STYLE Options: `none` (default, just message), `emoji` (prepends ❌), `level` (prepends [ERROR]).
log_error() {
  case "$LOG_STYLE" in
    emoji) _logger_output "❌  $*" ;;
    level) _logger_output "[ERROR] $*" ;;
    *)     _logger_output "$*" ;;
  esac
}

## log_info
#
# Logs an informational message. The output format depends on the `LOG_STYLE` environment variable.
#
# @param $@ The message to log.
# @env LOG_STYLE Options: `none` (default, just message), `emoji` (prepends ℹ️), `level` (prepends [INFO]).
log_info() {
  case "$LOG_STYLE" in
    emoji) _logger_output "ℹ️  $*" ;;
    level) _logger_output "[INFO] $*" ;;
    *)     _logger_output "$*" ;;
  esac
}

## log_success
#
# Logs a success message. The output format depends on the `LOG_STYLE` environment variable.
#
# @param $@ The message to log.
# @env LOG_STYLE Options: `none` (default, just message), `emoji` (prepends ✅), `level` (prepends [SUCCESS]).
log_success() {
  case "$LOG_STYLE" in
    emoji) _logger_output "✅  $*" ;;
    level) _logger_output "[SUCCESS] $*" ;;
    *)     _logger_output "$*" ;;
  esac
}

## log_warn
#
# Logs a warning message. The output format depends on the `LOG_STYLE` environment variable.
#
# @param $@ The message to log.
# @env LOG_STYLE Options: `none` (default, just message), `emoji` (prepends ⚠️), `level` (prepends [WARN]).
log_warn() {
  case "$LOG_STYLE" in
    emoji) _logger_output "⚠️  $*" ;;
    level) _logger_output "[WARN] $*" ;;
    *)     _logger_output "$*" ;;
  esac
}
