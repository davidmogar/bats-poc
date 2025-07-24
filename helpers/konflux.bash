#!/usr/bin/env bash

source helpers/logger.bash

get_build_pipeline_run_by_sha() {
  local sha="$1"
  local namespace="$2"
  local desired_status="${3:-Running}"
  local timeout="${4:-300}"
  local interval="${5:-5}"

  if [[ -z "${sha}" || -z "${namespace}" ]]; then
    log_error "Commit SHA and namespace are required"
    return 1
  fi

  local start_time
  start_time=$(date +%s)

  log_info "Waiting for PipelineRun with SHA=${sha} and status=${desired_status}"

  local pr_name=""
  while [[ -z "${pr_name}" ]]; do
    local now
    now=$(date +%s)
    local elapsed=$((now - start_time))

    if (( elapsed >= timeout )); then
      echo
      log_error "Timeout waiting for PipelineRun with SHA '${sha}' after ${timeout}s." >&2
      return 1
    fi

    sleep "${interval}"

    pr_name=$(kubectl get pipelinerun -n "${namespace}" \
      -l "pipelinesascode.tekton.dev/sha=${sha}" \
      --ignore-not-found --no-headers 2>/dev/null | \
      { grep "${desired_status}" || true; } | awk '{print $1}' | head -n1)
  done

  log_success "Found build PipelineRun: ${pr_name}"
  echo "${pr_name}"
}

get_build_pipeline_run_url() {
  local application="$1"
  local namespace="$2"
  local pipeline_run="$3"

  local console_url
  console_url=$(kubectl config view --minify --output jsonpath="{.clusters[*].cluster.server}" \
    | sed 's/api/konflux-ui.apps/g' | sed 's/:6443//g')
  console_url=${console_url%/}

  if [[ -z "${console_url}" ]]; then
    log_warn "Could not retrieve custom-console-url. URL might be incomplete"
    log_debug "kubectl get cm/pipelines-as-code -n openshift-pipelines -o json" \
      "${namespace}/applications/${application}/pipelineruns/${pipeline_run}"
    return 0
  fi

  echo "${console_url}/ns/${namespace}/applications/${application}/pipelineruns/${pipeline_run}"
}

wait_for_component_initialization() {
  local component="$1"
  local namespace="$2"
  local max_attempts="${3:-60}"
  local interval="${4:-5}"

  if [[ -z "${component}" || -z "${namespace}" ]]; then
    log_error "Component name and namespace are required."
    return 1
  fi

  local attempt=0

  while (( attempt < max_attempts )); do
    attempt=$((attempt+1))

    local status_json
    status_json=$(kubectl get component/"${component}" -n "${namespace}" -o json --ignore-not-found 2> /dev/null | \
      jq -r --arg k "build.appstudio.openshift.io/status" '.metadata.annotations[$k] // ""')

    if [[ -z "${status_json}" ]]; then
      log_warn "Component '${component}' not found in namespace '${namespace}' (attempt ${attempt}/${max_attempts})"
    else
      local merge_url
      merge_url=$(jq -r '.pac."merge-url" // empty' <<<"${status_json}" 2>/dev/null)

      if [[ -n "$merge_url" && "$merge_url" =~ /pull/([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
      else
        log_warn "Could not get component PR from the status. Requesting a new configure-pac... (attempt ${attempt}/${max_attempts})"
        kubectl annotate component "${component}" \
          build.appstudio.openshift.io/request=configure-pac \
          -n "${namespace}" --overwrite > /dev/null
      fi
    fi

    if (( attempt < max_attempts )); then
      sleep "$interval"
    fi
  done

  log_error "Failed to find PR annotation in component '${component}' after ${max_attempts} attempts."
  return 1
}

wait_for_releases_completion() {
  local pipeline_run="$1"
  local namespace="$2"
  local timeout="${3:-300}"
  local interval="${4:-5}"
  local elapsed=0

  log_info "Waiting for Releases created by PipelineRun '${pipeline_run}' in namespace '${namespace}' to appear..."

  while true; do
    releases=$(kubectl get release -n "${namespace}" -l "appstudio.openshift.io/build-pipelinerun=${pipeline_run}" -o json)
    if [[ "$(echo "$releases" | jq '.items | length')" -gt 0 ]]; then
      break
    fi

    if ((elapsed >= timeout)); then
      log_error "Timed out waiting for releases to be created"
      return 1
    fi

    sleep "$interval"
    ((elapsed+=interval))
  done

  log_info "Releases appeared, waiting indefinitely for their completion..."

  while true; do
    releases=$(kubectl get release -n "${namespace}" -l "appstudio.openshift.io/build-pipelinerun=${pipeline_run}" -o json)

    failed_releases=$(echo "$releases" | jq -r '.items[] | select(.status.conditions[]?.reason == "Failed") | .metadata.name')
    completed_releases=$(echo "$releases" | jq -r '.items[] | select(.status.completionTime != null) | .metadata.name')

    if [[ -n "$failed_releases" ]]; then
      log_error "Some releases failed: $failed_releases"
      return 1
    fi

    total_releases=$(echo "$releases" | jq '.items | length')
    completed_count=$(echo "$completed_releases" | wc -l | xargs)

    if [[ "${total_releases}" -eq "$completed_count" ]]; then
      log_success "All releases succeeded"
      echo "$completed_releases" | paste -sd ' ' -
      return 0
    fi

    log_debug "${completed_count} out of ${total_releases} Releases completed"
    sleep "$interval"
  done
}
