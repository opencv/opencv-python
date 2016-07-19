# Define custom utilities
# Test for OSX with [ -n "$IS_OSX" ]

function pre_build {
  if [ -n "$IS_OSX" ]; then
    echo "Don't know how to build for OSX yet..."
  else
    source travis/build-wheels.sh
  fi
}

function run_tests {
    # Runs tests on installed distribution from an empty directory
    python --version
    python -c 'import sys; import yourpackage; sys.exit(yourpackage.test())'
}
