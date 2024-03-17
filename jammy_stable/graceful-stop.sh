#!/bin/bash
RUNNER_GRACEFUL_STOP_TIMEOUT=${RUNNER_GRACEFUL_STOP_TIMEOUT:-30}

graceful_stop_term() {
  local runner_removal_token="${1}"
  log.notice "Executing actions-runner's SIGTERM handler."

  log.notice "Ensuring dockerd is still running."
  if ! docker ps -a; then
    log.warning "Detected configuration error: dockerd should be running but is already nowhere. This is wrong. Ensure that your init system to NOT pass SIGTERM directly to dockerd!"
  fi

  # The below procedure atomically removes the runner from GitHub Actions service,
  # to ensure that the runner is not running any job.
  # This is required to not terminate the actions runner agent while running the job.
  # If we didn't do this atomically, we might end up with a rare race where
  # the runner agent is terminated while it was about to start a job.

  # `pushd`` is needed to run the config.sh successfully.
  # Without this the author of this script ended up with errors like the below:
  #   Cannot connect to server, because config files are missing. Skipping removing runner from the server.
  #   Does not exist. Skipping Removing .credentials
  #   Does not exist. Skipping Removing .runner
  if ! pushd ${RUNNER_HOME}; then
    log.error "Failed to pushd ${RUNNER_HOME}"
    exit 1
  fi

  # wait for the registration first.
  log.notice "Checking to see if the runner has already been registered..."
  j=0
  while [[ $j -lt $RUNNER_GRACEFUL_STOP_TIMEOUT ]]; do
    sleep 1
    if [ ! -f ${RUNNER_HOME}/.runner ]; then
      log.notice "still waiting for runner to register"
    else
      log.notice "Observed that the runner has been registered."
      break
    fi
    j=$((j + 1))
  done

  log.notice 'Removing runner using "config.sh remove ..."'
  if ! ${RUNNER_HOME}/config.sh remove --token ${runner_removal_token}; then
    i=0
    log.notice "Waiting for RUNNER_GRACEFUL_STOP_TIMEOUT=$RUNNER_GRACEFUL_STOP_TIMEOUT seconds until the runner agent to stop by itself."
    while [[ $i -lt $RUNNER_GRACEFUL_STOP_TIMEOUT ]]; do
      sleep 1
      if ! pgrep Runner.Listener >/dev/null; then
        log.notice "The runner agent stopped before RUNNER_GRACEFUL_STOP_TIMEOUT=$RUNNER_GRACEFUL_STOP_TIMEOUT"
        break
      fi
      i=$((i + 1))
    done
  else
    log.notice 'Removing runner using "config.sh remove ..." appears to have gone well. Continuing...'
  fi

  if ! popd; then
    log.error "Failed to popd from ${RUNNER_HOME}"
    exit 1
  fi

  if pgrep Runner.Listener >/dev/null; then
    # The below procedure fixes the runner to correctly notify the Actions service for the cancellation of this runner.
    # It enables you to see `Error: The operation was canceled.` in the worklow job log, in case a job was still running on this runner when the
    # termination is requested.
    #
    # Note though, due to how Actions work, no all job steps gets `Error: The operation was canceled.` in the job step logs.
    # Jobs that were still in the first `Stet up job` step` seem to get `Error: A task was canceled.`
    runner_listener_pid=$(pgrep Runner.Listener)
    log.notice "Sending SIGTERM to the actions runner agent ($runner_listener_pid)."
    kill -TERM "$runner_listener_pid"

    log.notice "SIGTERM sent. If the runner is still running a job, you'll probably see \"Error: The operation was canceled.\" in its log."
    log.notice "Waiting for the actions runner agent to stop."
    while pgrep Runner.Listener >/dev/null; do
      sleep 1
    done
  fi

  # This message is supposed to be output only after the runner agent output:
  #   YYYY-MM-DD HH:MM:SS: Job ttxxxx completed with result: Canceled
  # because this graceful stopping logic is basically intended to let the runner agent have some time
  # needed to "Cancel" it.
  # At the times we didn't have this logic, the runner agent was even unable to output the Cancelled message hence
  # unable to gracefully stop, hence the workflow job hanged like forever.
  log.notice "The actions runner process exited."

  if [ "$RUNNER_INIT_PID" != "" ]; then
    log.notice "Holding on until runner init (pid $RUNNER_INIT_PID) exits, so that there will hopefully be no zombie processes remaining."
    # We don't need to kill -TERM $RUNNER_INIT_PID as the init is supposed to exit by itself once the foreground process(=the runner agent) exists.
    wait "$RUNNER_INIT_PID" || :
  fi

  log.notice "Graceful stop completed."
}
