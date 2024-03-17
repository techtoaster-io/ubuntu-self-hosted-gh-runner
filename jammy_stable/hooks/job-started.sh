#!/usr/bin/env bash
set -Eeuo pipefail

source logger.sh

log.debug "Running Job Started Hooks"

for hook in /etc/actions-runner/hooks/job-started.d/*; do
  log.debug "Running hook: $hook"
  "$hook" "$@"
done
