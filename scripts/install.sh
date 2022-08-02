#!/bin/bash

set -e
# Check out and prepare the source
# Multibuild doesn't have releases, so --depth would break eventually (see
# https://superuser.com/questions/1240216/server-does-not-allow-request-for-unadvertised)
git submodule update --init --recursive
source multibuild/common_utils.sh
# https://github.com/matthew-brett/multibuild/issues/116
if [[ "$TRAVIS_OS_NAME" == "osx" ]]; then export ARCH_FLAGS=" "; fi
source multibuild/travis_steps.sh
# This sets -x
# source travis_multibuild_customize.sh
echo $ENABLE_CONTRIB > contrib.enabled
echo $ENABLE_HEADLESS > headless.enabled
echo $ENABLE_ROLLING > rolling.enabled
set -x
install_run $PLAT
set +x
