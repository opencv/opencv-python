#!/bin/bash
set +e
echo "===  Loading config.sh  === "

if [ -n "$IS_OSX" ]; then
  echo "    > OSX environment "
  function build_wheel {
      # Custom build_wheel function for OSX
      # Run using '.' instead of '$REPO_DIR' to build from
      # opencv-python instead of opencv
      build_pip_wheel . $@
  }
else
  echo "    > Linux environment "
fi

function pre_build {
  echo "Starting pre-build"

  set +e
  if [ -n "$IS_OSX" ]; then
    echo "Running for OSX"
    source travis/build-wheels-osx.sh
  else
    echo "Running for linux"
    source /io/travis/build-wheels.sh
  fi
}

function run_tests {
    # Runs tests on installed distribution from an empty directory
    # python --version
    # python -c 'import sys; import yourpackage; sys.exit(yourpackage.test())'
    set +e
    echo "Run tests..."
    echo $PWD
    ls -lh

    if [ -n "$IS_OSX" ]; then
      echo "Running for OS X"
      cd ../tests/
      source ../travis/test-wheels.sh
    else
      echo "Running for linux"
      apt-get update
      apt-get -y install --fix-missing libglib2.0-0 libsm6
      cd /io/tests/
      source /io/travis/test-wheels.sh
    fi
}
