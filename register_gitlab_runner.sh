#!/bin/bash
set -euo pipefail

# Registers a GitLab Runner against a GitLab instance with a self-signed /
# untrusted certificate, skipping TLS verification.
#
# Required env vars:
#   GITLAB_URL                 e.g. https://gitlab.internal.example.com
#   GITLAB_REGISTRATION_TOKEN  project or group registration token
#
# Optional env vars:
#   RUNNER_DESCRIPTION  (default: rhel-hardening-runner)
#   RUNNER_TAGS         (default: rhel-hardening,aws)
#   RUNNER_EXECUTOR     (default: shell)

: "${GITLAB_URL:?Set GITLAB_URL, e.g. https://gitlab.internal.example.com}"
: "${GITLAB_REGISTRATION_TOKEN:?Set GITLAB_REGISTRATION_TOKEN}"

RUNNER_DESCRIPTION="${RUNNER_DESCRIPTION:-rhel-hardening-runner}"
RUNNER_TAGS="${RUNNER_TAGS:-rhel-hardening,aws}"
RUNNER_EXECUTOR="${RUNNER_EXECUTOR:-shell}"

if ! command -v gitlab-runner &>/dev/null; then
    echo "gitlab-runner is not installed. Install it first:"
    echo "  https://docs.gitlab.com/runner/install/linux-repository.html"
    exit 1
fi

echo "Registering GitLab Runner against ${GITLAB_URL} (TLS verification disabled)..."

sudo gitlab-runner register \
    --non-interactive \
    --url "${GITLAB_URL}" \
    --registration-token "${GITLAB_REGISTRATION_TOKEN}" \
    --executor "${RUNNER_EXECUTOR}" \
    --description "${RUNNER_DESCRIPTION}" \
    --tag-list "${RUNNER_TAGS}" \
    --run-untagged="false" \
    --locked="false" \
    --tls-skip-verify

# --tls-skip-verify covers the runner's calls back to the GitLab API.
# git clone TLS verification is handled separately, via GIT_SSL_NO_VERIFY
# set in .gitlab-ci.yml's top-level `variables`.

echo "Done. Runner '${RUNNER_DESCRIPTION}' registered with tags: ${RUNNER_TAGS}"
