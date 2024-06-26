#!/bin/bash

set -eu

source logger.sh

GITHUB_DOMAIN=${GITHUB_DOMAIN:-https://github.com}
RUNNER_DEFAULT_LABEL="self-hosted,Linux,X64"
RUNNER_LABELS=${RUNNER_LABELS:-}
RUNNER_GROUPS=${RUNNER_GROUPS:-}

function wait_for_process () {
    local max_time_wait=30
    local process_name="$1"
    local waited_sec=0

    while ! pgrep "$process_name" >/dev/null && ((waited_sec < max_time_wait)); do
        log.debug  "Process $process_name is not running yet. Retrying in 1 seconds"
        log.debug  "Waited $waited_sec seconds of $max_time_wait seconds"
        sleep 1
        ((waited_sec=waited_sec+1))
        if ((waited_sec >= max_time_wait)); then
            return 1
        fi
    done
    return 0
}

function requiredArgumentCheck() {
  ARG_VAR_NAME=$1

  if [ -z "${!ARG_VAR_NAME+x}" ]; then
      log.error "[Error] '${ARG_VAR_NAME}' must be set" 1>&2
      exit 1
  fi
}

requiredArgumentCheck "GITHUB_PERSONAL_TOKEN"
requiredArgumentCheck "RUNNER_ORG"
requiredArgumentCheck "RUNNER_REPO"

# Start Docker daemon if needed
if [ "$#" -eq 1 ] && [ "$1" == "dind" ]; then
  shift
  RUNNER_DEFAULT_LABEL="${RUNNER_DEFAULT_LABEL},dind"
  log.debug "RUNNER_DEFAULT_LABEL : ${RUNNER_DEFAULT_LABEL}"

  # Start Docker daemon in the background
  sudo dockerd &

  log.debug 'Waiting for processes to be running...'
  processes=(dockerd)

  for process in "${processes[@]}"; do
      if ! wait_for_process "$process"; then
          log.error "(Error) $process is not running after max time"
          exit 1
      else
          log.debug "$process is running"
      fi
  done
fi

log.debug "args: $*"
#exit 0

# configure url
if [ -n "${RUNNER_REPO}" ]; then
  auth_url="${GITHUB_DOMAIN}/api/v3/repos/${RUNNER_ORG}/${RUNNER_REPO}/actions/runners/registration-token"
  registration_url="${GITHUB_DOMAIN}/${RUNNER_ORG}/${RUNNER_REPO}"
else
  auth_url="${GITHUB_DOMAIN}/api/v3/orgs/${RUNNER_ORG}/actions/runners/registration-token"
  registration_url="${GITHUB_DOMAIN}/${RUNNER_ORG}"
fi

generate_token() {
  local payload
  local runner_token

  payload=$(curl \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_PERSONAL_TOKEN}" \
    "${auth_url}")
  runner_token=$(echo "${payload}" | jq .token --raw-output)

  if [ "${runner_token}" == "null" ]; then
    log.error "${payload}"
    exit 1
  fi

  echo "${runner_token}"
}

remove_runner() {
  ./config.sh remove --token "$(generate_token)"
}

RUNNER_TOKEN=$(generate_token)
log.debug "RUNNER_TOKEN=${RUNNER_TOKEN}"

runnerName="${RUNNER_ORG}-${RUNNER_REPO}-runner-$(openssl rand -hex 6)"
log.debug "Registering runner ${runnerName}"

if [ -n "${RUNNER_LABELS}" ] && [ "${RUNNER_LABELS}" != "\"\"" ]; then
  RUNNER_LABELS="${RUNNER_DEFAULT_LABEL},${RUNNER_LABELS}"
else
  RUNNER_LABELS="${RUNNER_DEFAULT_LABEL}"
fi
log.debug "RUNNER_LABELS=\"${RUNNER_LABELS}\""


if [ -z "${RUNNER_REPO}" ] && [ -n "${RUNNER_GROUP}" ];then
  RUNNER_GROUPS=${RUNNER_GROUP}
  log.debug "RUNNER_GROUPS=\"${RUNNER_GROUPS}\""
fi

./config.sh \
  --url "${registration_url}" \
  --name ${runnerName} \
  --token ${RUNNER_TOKEN} \
  --runnergroup "${RUNNER_GROUPS}" \
  --labels "${RUNNER_DEFAULT_LABEL},${RUNNER_LABELS}" \
  --unattended \
  --replace

trap 'remove_runner; exit 130' SIGINT
trap 'remove_runner; exit 143' SIGTERM

./run.sh "$*"
