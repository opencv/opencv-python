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

    echo 'Installing QT4'
    brew tap cartr/qt4
    brew tap-pin cartr/qt4
    brew install qt@4
    echo '-----------------'
    echo 'Installing FFmpeg'
    brew install ffmpeg --without-x264 --without-xvid --without-gpl
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
      # https://github.com/matthew-brett/multibuild/issues/106
      apt-get update
      apt-get -y install --fix-missing libglib2.0-0 libsm6
      
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