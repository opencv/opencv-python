# Define custom utilities
# Test for OSX with [ -n "$IS_OSX" ]

function pre_build {
  echo "Starting pre-build"

  if [ -n "$IS_OSX" ]; then
    echo "Don't know how to build for OSX yet..."
    # source travis/build-wheels-osx.sh
  else
    echo "Running for linux"
    source /io/travis/build-wheels.sh
  fi
}

function run_tests {
    # Runs tests on installed distribution from an empty directory
    # python --version
    # python -c 'import sys; import yourpackage; sys.exit(yourpackage.test())'
    echo "Run tests..."
    echo $PWD
    ls -lh
    source /io/travis/test-wheels.sh
}
