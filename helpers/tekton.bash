#!/usr/bin/env bash

source helpers/logger.bash

## get_pipelinerun_condition_fields
#
# Retrieves the status, reason, and message fields of the "Succeeded" condition
# from a specified Tekton PipelineRun.
#
# @param $1 The name of the PipelineRun.
# @param $2 The Kubernetes namespace of the PipelineRun.
# @stdout The status, reason, and message of the "Succeeded" condition, space-separated.
#         Returns an empty string if the PipelineRun is not found or the condition is not present.
get_pipelinerun_condition_fields() {
  local name="$1"
  local namespace="$2"

  kubectl get pipelinerun "${name}" -n "${namespace}" \
    --ignore-not-found \
    -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status} {.status.conditions[?(@.type=="Succeeded")].reason} {.status.conditions[?(@.type=="Succeeded")].message}' \
    2>/dev/null || true
}

## wait_for_pipeline_run_completion
#
# Waits for a specified Tekton PipelineRun to complete, checking its "Succeeded" condition.
# It polls the PipelineRun's status with a configurable timeout and interval.
#
# @param $1 The name of the PipelineRun.
# @param $2 The Kubernetes namespace of the PipelineRun.
# @param $3 Optional. The maximum time in seconds to wait for completion. Defaults to 1800 (30 minutes).
# @param $4 Optional. The interval in seconds between checks. Defaults to 5.
# @stdout Informational messages about the waiting process and completion status.
# @stderr Error messages if a timeout occurs or the PipelineRun fails.
# @exitcode 0 if the PipelineRun succeeds, 1 if it fails or times out.
wait_for_pipeline_run_completion() {
  local name="$1"
  local namespace="$2"
  local timeout="${3:-1800}"
  local interval="${4:-5}"
  local elapsed=0

  log_info "Waiting for PipelineRun '${name}' in namespace '${namespace}' to complete..."

  while true; do
    local status reason message
    read -r status reason message <<< "$(get_pipelinerun_condition_fields "${name}" "${namespace}")"

    if [[ "$status" == "True" || "$status" == "False" ]]; then
      break
    fi

    if [[ "${timeout}" -gt 0 && "${elapsed}" -ge "${timeout}" ]]; then
      log_error "Timed out after ${elapsed}s while waiting for PipelineRun '${name}' to finish"
      return 1
    fi

    sleep "${interval}"
    (( elapsed += interval ))
  done

  if [[ "${reason}" == "Succeeded" ]]; then
    log_success "PipelineRun '${name}' completed successfully after ${elapsed}s"
    return 0
  else
    log_error "PipelineRun '${name}' failed after ${elapsed}s"
    log_debug "Reason: ${reason}"
    log_debug "Message: ${message}"
    return 1
  fi
}
