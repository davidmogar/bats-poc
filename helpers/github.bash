#!/usr/bin/env bash

source helpers/logger.bash

check_github_token() {
  if [[ -z "$GITHUB_TOKEN" ]]; then
    log_error "GITHUB_TOKEN is not set"
    return 1
  fi
}

_retry_curl() {
  local method="$1"
  local url="$2"
  local payload="${3:-}"
  local max_attempts=3
  local attempt=1

  while [[ ${attempt} -le ${max_attempts} ]]; do
    local response
    response=$(curl -sSfL \
      -X "${method}" \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      ${payload:+-d "${payload}"} \
      "${url}" 2>&1)

    if [[ $? -eq 0 ]]; then
      echo "${response}"
      return 0
    fi

    if [[ ${attempt} -lt ${max_attempts} ]]; then
      sleep 5
    fi
    attempt=$((attempt + 1))
  done

  log_error "GitHub API request failed after ${max_attempts} attempts to ${method} ${url}"
  return 1
}

create_github_branch() {
  local repo="$1"
  local base_branch="$2"
  local new_branch="$3"

  check_github_token || return 1

  local api_url="https://api.github.com/repos/${repo}"
  local ref_url="${api_url}/git/ref/heads/${base_branch}"

  local json
  json=$(_retry_curl GET "${ref_url}") || return 1
  local base_sha
  base_sha=$(jq -r '.object.sha' <<<"${json}")

  if [[ -z "${base_sha}" || "${base_sha}" == "null" ]]; then
    log_error "Could not retrieve SHA for base branch '${base_branch}'"
    return 1
  fi

  local payload
  payload=$(jq -n --arg ref "refs/heads/${new_branch}" --arg sha "${base_sha}" '{ ref: $ref, sha: $sha }')
  local create_url="${api_url}/git/refs"
  _retry_curl POST "${create_url}" "${payload}" >/dev/null \
    && log_success "Branch '${new_branch}' created from '${base_branch}'" \
    || { log_error "Failed to create branch '${new_branch}'"; return 1; }
}

merge_github_pr() {
  local repo="$1"
  local pr_number="$2"
  local title="${3:-}"
  local message="${4:-}"

  check_github_token || return 1

  local api_url="https://api.github.com/repos/${repo}/pulls/${pr_number}/merge"
  local payload
  payload=$(jq -n \
    --arg title "${title}" \
    --arg message "${message}" \
    '{ commit_title: ${title}, commit_message: ${message} }')

  local json
  json=$(_retry_curl PUT "${api_url}" "${payload}") || return 1

  local sha
  sha=$(jq -r '.sha' <<<"${json}")
  if [[ -z "${sha}" || "${sha}" == "null" ]]; then
    log_error "Could not extract SHA from merge response"
    return 1
  fi

  echo "${sha}"
}

delete_github_branch() {
  local repo="$1"
  local branch="$2"

  check_github_token || return 1

  local api_url="https://api.github.com/repos/${repo}/git/refs/heads/${branch}"
  _retry_curl DELETE "${api_url}" >/dev/null \
    && log_success "Branch '${branch}' deleted successfully" \
    || { log_error "Failed to delete branch '${branch}'"; return 1; }
}
