#!/bin/bash
#Customize multibuild logic that is run after entering docker.
#Sourced by docker_build_wrap.sh and docker_test_wrap.sh .
#Runs in Docker, so only the vars passed to `docker run' exist.
#See multibuild/README.rst
echo "===  Loading config.sh  === "

# To see build progress
function build_wheel {
    build_bdist_wheel $@
}

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

    # For some reason, gt@4 and ffmpeg can be preinstalled in Travis Mac env
    echo 'Installing QT4'
    brew tap | grep -qxF cartr/qt4 || brew tap -v cartr/qt4
    brew tap --list-pinned | grep -qxF cartr/qt4 || brew tap-pin -v cartr/qt4
    brew list --versions qt@4 || brew install -v qt@4
    echo '-----------------'
    echo 'Installing FFmpeg'
    # brew install does produce output regularly on a regular MacOS,
    # but Travis doesn't see it for some reason
    brew list --versions ffmpeg || \
    travis_wait brew install -v ffmpeg --without-x264 --without-xvid --without-gpl
    brew info ffmpeg
    echo '-----------------'
  else
    echo "Running for linux"
  fi
  qmake -query  
}

function run_tests {
    # Runs tests on installed distribution from an empty directory
    echo "Run tests..."
    echo $PWD

    if [ -n "$IS_OSX" ]; then
      echo "Running for OS X"
      cd ../tests/
    else
      echo "Running for linux"
      cd /io/tests/
    fi
    
    test_wheels
}

function test_wheels {
    PYTHON=python$PYTHON_VERSION

    echo "Starting tests..."

    #Test package
    $PYTHON -m unittest test
}

export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x