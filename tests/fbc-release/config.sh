UUID="$(openssl rand -hex 4)"

# Namespaces
TENANT_NAMESPACE="dev-release-team-tenant"
#
## Since this is a test that requires internal services,
## this name should not change.
#
MANAGED_NAMESPACE="managed-release-team-tenant"

APPLICATION_NAME="e2eapp-${UUID}"
COMPONENT_TYPE="fbc-release"
COMPONENT_NAME=""${COMPONENT_TYPE}-${UUID}""
COMPONENT_BRANCH=""${COMPONENT_NAME}""
## do not change this. it is a known branch created by Konflux
APPSTUDIO_COMPONENT_BRANCH="appstudio-${COMPONENT_NAME}"

COMPONENT_BASE_BRANCH="fbc-release-base"
COMPONENT_REPO_NAME="davidmogar/e2e-base" #konflux-ci/release-service-catalog-e2e-base
COMPONENT_GIT_URL="https://github.com/$COMPONENT_REPO_NAME"

TENANT_SA_NAME="fbc-release-sa-${UUID}"
RELEASE_PLAN_HAPPY_NAME="fbc-release-happy-rp-${UUID}"
RELEASE_PLAN_HOTFIX_NAME="fbc-release-hotfix-rp-${UUID}"
RELEASE_PLAN_PREGA_NAME="fbc-release-prega-rp-${UUID}"
RELEASE_PLAN_STAGED_NAME="fbc-release-staged-rp-${UUID}"

MANAGED_SA_NAME="fbc-release-sa-${UUID}"
RELEASE_PLAN_ADMISSION_HAPPY_NAME="fbc-release-happy-rpa-${UUID}"
RELEASE_PLAN_ADMISSION_HOTFIX_NAME="fbc-release-hotfix-rpa-${UUID}"
RELEASE_PLAN_ADMISSION_PREGA_NAME="fbc-release-prega-rpa-${UUID}"
RELEASE_PLAN_ADMISSION_STAGED_NAME="fbc-release-staged-rpa-${UUID}"

RELEASE_PLAN_HAPPY_AUTO_RELEASE="true"
RELEASE_PLAN_HOTFIX_AUTO_RELEASE="true"
RELEASE_PLAN_PREGA_AUTO_RELEASE="true"
RELEASE_PLAN_STAGED_AUTO_RELEASE="true"
