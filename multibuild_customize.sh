#!/bin/bash
# Customize multibuild logic that is run before entering Docker. Sourced from travis.yml .
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x
REPO_DIR=$(dirname "${BASH_SOURCE[0]}")
BUILD_COMMIT=$(git rev-parse HEAD)
DOCKER_IMAGE='quay.io/skvark/manylinux_$plat'

