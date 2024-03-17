#!/usr/bin/env bash

set -Eeuo pipefail

DOCKER=/usr/bin/docker

exec $DOCKER "$@"
