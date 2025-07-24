#!/usr/bin/env bash

source helpers/logger.bash

## apply_kustomized_resources
#
# Applies Kubernetes resources defined by a `kustomization.yaml` file within a given directory.
# This function copies the resources to an output directory, performs environment variable
# substitution on YAML files, adds a `created-by: release-test-suite` label to the
# `kustomization.yaml`, and then applies the kustomized resources using `kubectl apply -k`.
#
# @param $1 The source directory containing the `kustomization.yaml` and related resources.
# @param $2 The output directory where resources will be copied and processed.
# @stdout Success message indicating resources have been applied.
# @stderr Error messages if usage is incorrect, `kustomization.yaml` is not found, or `kubectl` fails.
# @exitcode 0 if resources are applied successfully, 1 otherwise.
apply_kustomized_resources() {
  local resource_dir="$1"
  local output_dir="$2"

  if [[ -z "${resource_dir}" || -z "${output_dir}" ]]; then
    log_error "Usage: apply_kustomized_resources <resource_dir> <output_dir>"
    return 1
  fi

  if [[ ! -f "${resource_dir}/kustomization.yaml" ]]; then
    log_error "No kustomization.yaml found in ${resource_dir}"
    return 1
  fi

  mkdir -p "${output_dir}"
  cp -r "${resource_dir}/." "${output_dir}"

  find "${output_dir}" -type f -name "*.yaml" | while read -r file; do
    envsubst < "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
  done

  yq eval '.labels[0].pairs."created-by" = "release-test-suite"' -i "${output_dir}/kustomization.yaml"

  kubectl apply -k "${output_dir}"

  log_success "Resources applied from ${output_dir}"
}

## delete_kustomization_resources
#
# Deletes Kubernetes resources previously applied via a `kustomization.yaml` file.
# This function requires a directory containing a `kustomization.yaml` and uses
# `kubectl delete -k` to remove the resources.
#
# @param $1 The directory containing the `kustomization.yaml` from which to delete resources.
# @stdout Informational message about the deletion process.
# @stderr Error messages if the directory does not exist or if `kustomization.yaml` is not found.
# @exitcode 0 if deletion command is executed, 1 otherwise.
delete_kustomization_resources() {
  local resource_dir="$1"

  if [[ -z "${resource_dir}" || ! -d "${resource_dir}" ]]; then
    log_error "Error: Directory '${resource_dir}' does not exist."
    return 1
  fi

  if [[ ! -f "${resource_dir}/kustomization.yaml" ]]; then
    log_error "Error: No kustomization.yaml file found in '${resource_dir}'."
    return 1
  fi

  log_info "Deleting resources defined in '${resource_dir}/kustomization.yaml'..."
  kubectl delete -k "${resource_dir}"
}
