#!/bin/bash
#Customize multibuild logic that is run after entering docker.
#Sourced by docker_build_wrap.sh . Runs in Docker, so only the vars passed to `docker run' exist.
#See multibuild/README.rst
echo "===  Loading config.sh  === "

# To see build progress
function build_wheel {
    build_bdist_wheel $@
}

export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x

if [ -n "$IS_OSX" ]; then
  echo "    > OSX environment "
else
  echo "    > Linux environment "
fi

function pre_build {
  echo "Starting pre-build"
  set -e

  if [ -n "$IS_OSX" ]; then
    echo "Running for OSX"
    #source travis/build-wheels-osx.sh
    brew tap cartr/qt4
    brew tap-pin cartr/qt4
    brew install qt@4
  else
    echo "Running for linux"
    #source /io/travis/build-wheels.sh
  fi
  qmake -query  
}

function run_tests {
    # Runs tests on installed distribution from an empty directory
    # python --version
    # python -c 'import sys; import yourpackage; sys.exit(yourpackage.test())'
    echo "Run tests..."
    echo $PWD
    ls -lh

    if [ -n "$IS_OSX" ]; then
      echo "Running for OS X"
      cd ../tests/
      source ../travis/test-wheels.sh
    else
      echo "Running for linux"
      #apt-get update
      #apt-get -y install --fix-missing libglib2.0-0 libsm6
      cd /io/tests/
      source /io/travis/test-wheels.sh
    fi
}
