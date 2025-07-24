#!/usr/bin/env bats

load '../../helpers/common'

setup_file() {
  _common_setup_file
}

teardown_file() {
  _common_teardown_file
}

setup() {
  _common_setup
}

@test "Component is initialized" {
  GITHUB_PR=$(wait_for_component_initialization "$COMPONENT_NAME" "$TENANT_NAMESPACE")
 _save_var GITHUB_PR
}

@test "Component PR is merged" {
  SHA=$(merge_github_pr "$COMPONENT_REPO_NAME" "${GITHUB_PR}" "pr merged by bats" "This pr has been merged by bats")
  _save_var SHA
}

@test "Build PipelineRun completes successfully" {
  BUILD_PIPELINE_RUN="$(get_build_pipeline_run_by_sha "${SHA}" "$TENANT_NAMESPACE")"
  _save_var BUILD_PIPELINE_RUN

  url=$(get_build_pipeline_run_url "$APPLICATION_NAME" "$TENANT_NAMESPACE" "${BUILD_PIPELINE_RUN}")
  log_success "Build PipelineRun: ${url}"

  wait_for_pipeline_run_completion "${BUILD_PIPELINE_RUN}" "$TENANT_NAMESPACE"
}

@test "All releases succeeded" {
  local releases
  RELEASES=$(wait_for_releases_completion "$BUILD_PIPELINE_RUN" "$TENANT_NAMESPACE")
  _save_var RELEASES
}

@test "All releases are valid" {
  echo "$RELEASES"
  for release in $RELEASES;
  do
    log_debug "Verifying Release contents for ${release} in namespace ${TENANT_NAMESPACE}..."

    local release_json
    release_json=$(kubectl get release/"${release}" -n "${TENANT_NAMESPACE}" -o json)

    if [ -z "$release_json" ]; then
        log_error "Could not retrieve Release JSON for ${release}"
    fi

    run jq -er '.status.artifacts.components[0].fbc_fragment' <<< "${release_json}"
    assert_success

    run jq -er '.status.artifacts.components[0].ocp_version' <<< "${release_json}"
    assert_success

    run jq -er '.status.artifacts.components[0].iibLog' <<< "${release_json}"
    assert_success

    run jq -er '.status.artifacts.index_image.index_image' <<< "${release_json}"
    assert_success

    run jq -er '.status.artifacts.index_image.index_image_resolved' <<< "${release_json}"
    assert_success
  done
}
