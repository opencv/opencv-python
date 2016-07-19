#!/bin/bash
set +e
echo "===  Loading config.sh  === "
if [ -n "$IS_OSX" ]; then
  echo "    > OSX environment "
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
      echo "Dont know how to test for OSX yet..."
      source ../travis/test-wheels.sh
    else
      echo "Running for linux"
      source /io/travis/test-wheels.sh
    fi
}
