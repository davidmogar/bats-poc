#!/usr/bin/env bash

load '../../libs/bats-support/load'
load '../../libs/bats-assert/load'
load '../../helpers/config'
load '../../helpers/github'
load '../../helpers/konflux'
load '../../helpers/kubernetes'
load '../../helpers/paths'
load '../../helpers/tekton'
load '../../helpers/vault'

CLEANUP="${CLEANUP:-true}"

RESOURCES_PATH="$(_resolve_path "resources")"
GENERATED_RESOURCES_PATH="${RESOURCES_PATH}/generated"
RESOURCES_MANAGED_PATH="${RESOURCES_PATH}/managed"
RESOURCES_TENANT_PATH="${RESOURCES_PATH}/tenant"
VAULT_SECRETS_FILE_NAME="vault-secrets.yaml"

## _common_setup
#
# Loads the state file into the current shell session if it exists.
# This function is typically used at the beginning of a test or script
# to restore previous state.
#
# @exitcode 0 if the state file is loaded successfully or does not exist
_common_setup() {
  # shellcheck disable=SC1090
  [[ -f "$STATE_FILE" ]] && source "$STATE_FILE"
}

## _common_setup_file
#
# Initializes the test environment for a Bats file.
#
# This function performs the following actions:
# - Sets the `STATE_FILE` environment variable to a temporary file path.
# - Creates the `STATE_FILE`.
# - Loads configuration variables using `load_config`.
# - Checks for the existence of the `RESOURCES_PATH` directory.
# - Validates that `COMPONENT_REPO_NAME`, `COMPONENT_BASE_BRANCH`, and `COMPONENT_BRANCH` are set.
# - Decrypts secrets using `_decrypt_secrets`.
# - Creates a new GitHub branch.
# - Applies kustomized resources using `_apply_kustomized_resources`.
#
# @env STATE_FILE Path to the state file (set by the function).
# @env COMPONENT_REPO_NAME The name of the component repository.
# @env COMPONENT_BASE_BRANCH The base branch for the component.
# @env COMPONENT_BRANCH The new branch to be created for the component.
# @exitcode 0 if setup is successful, 1 if resources are not found or
#           required variables are not set.
# @stderr Error messages if resources are not found or required variables are not set.
_common_setup_file() {
  export STATE_FILE="${BATS_FILE_TMPDIR}/test_state.env"
  touch "$STATE_FILE"

  eval "$(load_config)"

  if [[ ! -d "${RESOURCES_PATH}" ]]; then
    echo "No resources found"
    return 1
  fi

  for var in RELEASE_CATALOG_GIT_URL RELEASE_CATALOG_GIT_REVISION COMPONENT_REPO_NAME COMPONENT_BASE_BRANCH COMPONENT_BRANCH; do
    if [[ -z "${!var}" ]]; then
      echo "Error: Required variable '$var' is not set or empty"
      return 1
    fi
  done

  _decrypt_secrets

  create_github_branch "$COMPONENT_REPO_NAME" "$COMPONENT_BASE_BRANCH" "$COMPONENT_BRANCH"

  _apply_kustomized_resources
}

## _common_teardown_file
#
# Cleans up the test environment.
#
# This function performs the following cleanup actions if the `CLEANUP` variable is not set to "false":
# - Deletes kustomization resources using `_delete_kustomization_resources`.
# - Removes generated resources using `_remove_generated_resources`.
# - Removes vault output files using `_remove_vault_output`.
# If `CLEANUP` is "false", a warning is logged and cleanup is skipped.
#
# @env CLEANUP If set to "false", skips all cleanup operations. Defaults to "true".
# @stdout Log messages indicating cleanup actions or skipping.
_common_teardown_file() {
  if [[ "${CLEANUP}" != "false" ]]; then
    log_debug "Running cleanup commands..."

    _delete_kustomization_resources
    _remove_generated_resources
    _remove_vault_output
  else
    log_warn "Skipping cleanup due to CLEANUP being set to false"
  fi
}

## _apply_kustomized_resources
#
# Applies kustomized resources from managed and tenant paths.
#
# This function uses `apply_kustomized_resources` to:
# - Apply resources from `RESOURCES_MANAGED_PATH` to `GENERATED_RESOURCES_PATH/managed`.
# - Apply resources from `RESOURCES_TENANT_PATH` to `GENERATED_RESOURCES_PATH/tenant`.
# The third argument `false` indicates that resources should not be deleted beforehand.
#
# @env RESOURCES_MANAGED_PATH Path to the managed resources.
# @env RESOURCES_TENANT_PATH Path to the tenant resources.
# @env GENERATED_RESOURCES_PATH Path where generated resources are stored.
_apply_kustomized_resources() {
  apply_kustomized_resources "${RESOURCES_MANAGED_PATH}" "${GENERATED_RESOURCES_PATH}/managed" false
  apply_kustomized_resources "${RESOURCES_TENANT_PATH}" "${GENERATED_RESOURCES_PATH}/tenant" false
}

## _decrypt_secrets
#
# Decrypts Vault secrets for managed and tenant resources.
#
# This function decrypts:
# - `vault/managed.yaml` secrets into `RESOURCES_MANAGED_PATH/vault-secrets.yaml`.
# - `vault/tenant.yaml` secrets into `RESOURCES_TENANT_PATH/vault-secrets.yaml`.
#
# @env VAULT_PASSWORD_FILE Path to the Vault password file.
# @env RESOURCES_MANAGED_PATH Path where managed resources are located.
# @env RESOURCES_TENANT_PATH Path where tenant resources are located.
# @env VAULT_SECRETS_FILE_NAME The name of the Vault secrets file (defaults to "vault-secrets.yaml").
# @exitcode 0 if decryption is successful, 1 if `VAULT_PASSWORD_FILE` is not set.
# @stderr Error message if `VAULT_PASSWORD_FILE` is not set.
_decrypt_secrets() {
  if [[ -z "${VAULT_PASSWORD_FILE}" ]]; then
    echo "VAULT_PASSWORD_FILE is not set"
    return 1
  fi

  decrypt_secrets "$(_resolve_path "vault/managed.yaml")" "${GENERATED_RESOURCES_PATH}/managed/${VAULT_SECRETS_FILE_NAME}"
  decrypt_secrets "$(_resolve_path "vault/tenant.yaml")" "${GENERATED_RESOURCES_PATH}/tenant/${VAULT_SECRETS_FILE_NAME}"
}

## _delete_kustomization_resources
#
# Deletes kustomization-applied resources from generated paths.
#
# This function removes resources previously applied from:
# - `GENERATED_RESOURCES_PATH/managed`
# - `GENERATED_RESOURCES_PATH/tenant`
#
# @env GENERATED_RESOURCES_PATH Path where generated resources are stored.
_delete_kustomization_resources() {
  delete_kustomization_resources "${GENERATED_RESOURCES_PATH}/managed"
  delete_kustomization_resources "${GENERATED_RESOURCES_PATH}/tenant"
}

## _remove_generated_resources
#
# Removes all generated resource files and directories.
#
# This function deletes the content of the `GENERATED_RESOURCES_PATH` directory.
#
# @env GENERATED_RESOURCES_PATH Path to the directory containing generated resources.
_remove_generated_resources() {
  rm -rf "${GENERATED_RESOURCES_PATH:?}"
}

## _remove_vault_output
#
# Removes the decrypted Vault secrets files.
#
# This function deletes:
# - The `vault-secrets.yaml` file from `RESOURCES_MANAGED_PATH`.
# - The `vault-secrets.yaml` file from `RESOURCES_TENANT_PATH`.
#
# @env RESOURCES_MANAGED_PATH Path where managed resources are located.
# @env RESOURCES_TENANT_PATH Path where tenant resources are located.
# @env VAULT_SECRETS_FILE_NAME The name of the Vault secrets file (defaults to "vault-secrets.yaml").
_remove_vault_output() {
  rm -rf "${RESOURCES_MANAGED_PATH}/${VAULT_SECRETS_FILE_NAME:?}"
  rm -rf "${RESOURCES_TENANT_PATH}/${VAULT_SECRETS_FILE_NAME:?}"
}

## _save_var
#
# Saves the value of a given variable to the state file.
#
# The variable's name and its current value are written to the `STATE_FILE`
# in a format suitable for sourcing (e.g., `VAR_NAME='VAR_VALUE'`).
#
# @param $1 The name of the variable to save.
# @env STATE_FILE Path to the state file where the variable will be saved.
_save_var() {
  local var="$1"
  local val="${!var}"
  echo "${var}='${val}'" >> "$STATE_FILE"
}
