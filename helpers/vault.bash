#!/usr/bin/env bash

source helpers/logger.bash

## decrypt_secrets
#
# Decrypts an Ansible Vault file into a specified output file.
#
# This function takes the path to an encrypted Vault file, an output path for
# the decrypted content, and an optional path to the vault password file.
# It checks for the existence of the input files and creates the output directory
# if necessary. If the vault file or the output file already exist, it logs a warning
# and skips the decryption.
#
# @param $1 The path to the Ansible Vault encrypted file.
# @param $2 The path where the decrypted content will be written.
# @param $3 Optional. The path to the vault password file. If not provided,
#           it defaults to the value of the `VAULT_PASSWORD_FILE` environment variable.
# @env VAULT_PASSWORD_FILE Default path to the vault password file if $3 is not provided.
# @stdout Informational and warning messages.
# @stderr Error messages if required files are not found.
# @exitcode 0 if decryption is successful or skipped, 1 if the password file is missing.
decrypt_secrets() {
  local vault_file="$1"
  local output_file="$2"
  local vault_password_file="${3:-$VAULT_PASSWORD_FILE}"

  if [[ ! -f "${vault_file}" ]]; then
    log_warning "Vault file ${vault_file} not found, skipping"
    return 0
  fi

  if [[ ! -f "${vault_password_file}" ]]; then
    lon_error "Vault password file ${vault_password_file} not found"
    return 1
  fi

  if [[ -f "${output_file}" ]]; then
    log_warning "Decrypted file ${output_file} already exists"
    return 0
  fi

  mkdir -p "$(dirname "${output_file}")"

  log_info "Decrypting ${vault_file} to ${output_file}"
  ansible-vault decrypt "${vault_file}" \
    --output "${output_file}" \
    --vault-password-file "${vault_password_file}"
}
