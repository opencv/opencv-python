#!/bin/bash
#Sourced by multibuild scripts. See multibuild/README.rst
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
    source travis/build-wheels-osx.sh
  else
    echo "Running for linux"
    #skbuild tries just "cmake"
    #wget --no-check-certificate https://cmake.org/files/v3.10/cmake-3.10.1-Linux-x86_64.tar.gz
    #tar -xf cmake-3.10.1-Linux-x86_64.tar.gz -C /opt
    #export PATH="/opt/cmake-3.10.1-Linux-x86_64/bin:$PATH"
    #ls -l /usr/local/bin
    #test -f /usr/local/bin/cmake || {
    #    mkdir -p /usr/local/bin
    #    cp -s "$(which cmake28)" /usr/local/bin/cmake; }
    #source /io/travis/build-wheels.sh
    #yum -y install cmake
  fi
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
