# Konflux E2E Release Test Suite

This repository contains an end-to-end (E2E) test suite for validating the Konflux release process. It uses Bats (Bash Automated Testing System) to orchestrate a series of operations, including GitHub interactions, Kubernetes resource management, and monitoring of Konflux-specific resources like PipelineRuns and Releases.

## Project Structure

```
.
├── helpers/                 # Collection of Bash helper scripts
│   ├── common.bash          # Common setup/teardown and state management
│   ├── config.bash          # Functions for loading configuration (YAML/Bash)
│   ├── github.bash          # GitHub API interaction functions (branching, merging)
│   ├── konflux.bash         # Functions for interacting with Konflux-specific resources (e.g., Releases)
│   ├── kubernetes.bash      # Kubernetes resource management (apply, delete kustomizations)
│   ├── logger.bash          # Logging utility functions
│   ├── paths.bash           # Path resolution utilities
│   ├── tekton.bash          # Tekton-specific functions (PipelineRun monitoring)
│   └── vault.bash           # Ansible Vault decryption utilities
├── libs/                    # External Bats libraries
│   ├── bats-assert/         # Assertion library for Bats tests
│   └── bats-support/        # Support library for Bats tests
└── tests/                   # Contains the actual E2E test suites
    └── fbc-release/         # Specific test suite for FBC release process
        ├── config.sh        # Test-specific configuration
        ├── resources/       # Kubernetes resources used by the test
        │   ├── generated/   # Directory for generated Kubernetes manifests
        │   ├── managed/     # Managed Kubernetes resources
        │   └── tenant/      # Tenant-specific Kubernetes resources
        ├── test.bats        # The main Bats test file for fbc-release
        └── vault/           # Encrypted Vault files
            ├── managed.yaml
            └── tenant.yaml
```

## Prerequisites

Before running the tests, ensure you have the following installed and configured:

1.  **Bats-core**: The Bash Automated Testing System.
    * **Installation:**
      ```bash
      git clone https://github.com/bats-core/bats-core.git
      cd bats-core
      sudo ./install.sh /usr/local
      ```
    * Verify installation: `bats --version`
2.  **`kubectl`**: Kubernetes command-line tool, configured to access your Konflux cluster.
3.  **`jq`**: A lightweight and flexible command-line JSON processor.
    * **Installation (macOS):** `brew install jq`
    * **Installation (Linux - Debian/Ubuntu):** `sudo apt-get install jq`
4.  **`yq`**: A portable YAML processor.
    * **Installation (using `go install`):** `go install github.com/mikefarah/yq/v4@latest`
    * **Installation (other methods):** See [yq documentation](https://www.google.com/search?q=https://mikefarah.gitbook.io/yq/%23install)
5.  **`curl`**: Typically pre-installed on most systems.
6.  **`envsubst`**: From the `gettext` package, used for environment variable substitution.
    * **Installation (macOS):** `brew install gettext && brew link --force gettext`
    * **Installation (Linux - Debian/Ubuntu):** `sudo apt-get install gettext-base`
7.  **`ansible-vault`**: Part of Ansible, used for decrypting secrets.
    * **Installation:** `pip install ansible`
8.  **GitHub Token**: A GitHub Personal Access Token (PAT) with sufficient permissions to create and merge branches in the target repository. You'll need to export this as an environment variable.
9.  **Vault Password File**: A file containing the password for `ansible-vault`. This path also needs to be exported.

## Configuration

The tests rely on several environment variables. These can be set directly in your shell or loaded via a `config.sh` or `config.yaml` file within the test directory.

### Required Environment Variables

* **`GITHUB_TOKEN`**: Your GitHub Personal Access Token. This is crucial for the tests to interact with GitHub (e.g., creating branches, merging PRs).
    * Example: `export GITHUB_TOKEN="github_pat_YOUR_TOKEN_HERE"`
* **`RELEASE_CATALOG_GIT_URL`**: The URL of the Konflux Release Service Catalog Git repository.
    * Example: `export RELEASE_CATALOG_GIT_URL="https://github.com/konflux-ci/release-service-catalog"`
* **`RELEASE_CATALOG_GIT_REVISION`**: The specific Git revision (branch, tag, or commit SHA) of the release catalog to use.
    * Example: `export RELEASE_CATALOG_GIT_REVISION="development"`
* **`VAULT_PASSWORD_FILE`**: The absolute path to the file containing your Ansible Vault password.
    * Example: `export VAULT_PASSWORD_FILE=/path/to/your/vault_password_file`

### Logging Variables

The `helpers/logger.bash` script provides flexible logging. You can control its behavior with the following environment variables:

* **`VERBOSE`**: If set to `true`, enables verbose output for all logs. Defaults to `false`.
    * Example: `export VERBOSE=true`
* **`LOG_STYLE`**: Controls the formatting of log messages.
    * Options:
        * `none` (default): Simple output with a ` #  ` prefix.
        * `emoji`: Prepends emojis to log messages (e.g., `ℹ️`, `❌`, `✅`).
        * `level`: Prepends log levels (e.g., `[INFO]`, `[ERROR]`).
    * Example: `export LOG_STYLE=emoji`
* **`DEBUG`**: If set to `true`, enables debug messages and automatically sets `VERBOSE=true`. Defaults to `false`.
    * Example: `export DEBUG=true`

## General Usage

### Cloning the Repository

Since this repository uses Git submodules (for the `bats-assert` and `bats-support` libraries), you need to clone it with the `--recurse-submodules` flag to ensure all necessary components are downloaded:

```bash
git clone --recurse-submodules https://github.com/davidmogar/bats-poc.git
cd bats-poc
```

If you've already cloned the repository without this flag, you can initialize and update the submodules manually:

```bash
git submodule update --init --recursive
```

### Setting up the Environment

Before running any tests, make sure all [Required Environment Variables](https://www.google.com/search?q=%23required-environment-variables) are set in your shell.

```bash
# Example setup
export GITHUB_TOKEN="github_pat_11AALNYWY0BOKvvlHKI9R_mq8dCiIrojHbyOxpGK3S0shjxcQ4xjyZ5FwqV9RrrUOZPQCZ4Ne7tQBbPs"
export RELEASE_CATALOG_GIT_URL="https://github.com/konflux-ci/release-service-catalog"
export RELEASE_CATALOG_GIT_REVISION="development"
export VAULT_PASSWORD_FILE=/Users/damoreno/bats/vault_password_file

# Optional logging settings
export LOG_STYLE=emoji
export DEBUG=true
```

### Running the Tests

Navigate to the root directory of the repository and run Bats, pointing it to the desired test file.

To run the `fbc-release` test suite:

```bash
bats tests/fbc-release/test.bats
```

You can also run the tests using the tap formatter which outputs information immediately without waiting for the test to complete:

```bash
bats tests/fbc-release/test.bats
```

## Test Flow (fbc-release/test.bats)

The `tests/fbc-release/test.bats` suite performs the following sequence of operations:

1.  **`setup_file()`**:
    * Calls `_common_setup_file` (from `helpers/common.bash`). This:
        * Sets up a temporary state file (`STATE_FILE`).
        * Loads configuration from `config.sh` (or `config.yaml`) in the test directory.
        * Ensures necessary `RESOURCES_PATH` exists and `COMPONENT_REPO_NAME`, `COMPONENT_BASE_BRANCH`, `COMPONENT_BRANCH` are set.
        * Decrypts vault secrets (e.g., `vault/managed.yaml`, `vault/tenant.yaml`).
        * Creates a new GitHub branch for the component (`create_github_branch`).
        * Applies kustomized Kubernetes resources from `resources/managed` and `resources/tenant` to the cluster.
2.  **`setup()`**:
    * Calls `_common_setup` to source the state file, restoring variables saved from previous tests in the same run.
3.  **"Component is initialized"**:
    * Waits for the component to be initialized in Konflux, specifically looking for a Pull Request (PR) annotation on the component resource.
    * Saves the `GITHUB_PR` number to the state file.
4.  **"Component PR is merged"**:
    * Merges the GitHub Pull Request identified in the previous step, using the `GITHUB_PR` variable.
    * Saves the merge commit `SHA` to the state file.
5.  **"Build PipelineRun completes successfully"**:
    * Waits for a Tekton PipelineRun associated with the merged `SHA` to appear and complete successfully.
    * Prints the URL to the Konflux UI for the PipelineRun.
    * Saves the `BUILD_PIPELINE_RUN` name to the state file.
6.  **"All releases succeeded"**:
    * Waits for all Konflux Release objects created by the `BUILD_PIPELINE_RUN` to appear and complete successfully.
    * Saves the names of the successful `RELEASES` to the state file.
7.  **"All releases are valid"**:
    * Iterates through each successful Release and verifies that expected artifact fields (like `fbc_fragment`, `ocp_version`, `iibLog`, `index_image`, `index_image_resolved`) are present in its status.

Feel free to explore the `helpers/` directory for more details on each function used in the tests.
