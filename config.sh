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

function bdist_wheel_cmd {
    # copied from multibuild's common_utils.sh
    # add osx deployment target so it doesnt default to 10.6
    local abs_wheelhouse=$1
    python setup.py bdist_wheel $BDIST_PARAMS
    cp dist/*.whl $abs_wheelhouse
}

if [ -n "$IS_OSX" ]; then
  echo "    > OSX environment "
else
  echo "    > Linux environment "
fi

if [ -n "$IS_OSX" ]; then

    source travis_osx_brew_cache.sh
    
    BREW_SLOW_BUILIDING_PACKAGES=$(printf '%s\n' \
        "x265 20"  \
        "cmake 15" \
        "ffmpeg 10" \
    )
    
    #Contrib adds significantly to project's build time
    if [ "$ENABLE_CONTRIB" -eq 1 ]; then
        BREW_TIME_LIMIT=$((BREW_TIME_LIMIT - 10*60))
    fi
        
fi

function pre_build {
  echo "Starting pre-build"
  set -e -o pipefail

  if [ -n "$IS_OSX" ]; then
    echo "Running for OSX"
    
    brew update --merge
    brew_add_local_bottles

    # Don't query analytical info online on `brew info`,
    #  this takes several seconds and we don't need it
    # see https://docs.brew.sh/Manpage , "info formula" section
    export HOMEBREW_NO_GITHUB_API=1

    echo 'Installing QT4'
    brew tap | grep -qxF cartr/qt4 || brew tap -v cartr/qt4
    brew tap --list-pinned | grep -qxF cartr/qt4 || brew tap-pin -v cartr/qt4
    brew_install_and_cache_within_time_limit qt@4 || { [ $? -gt 1 ] && return 2 || return 0; }

    echo 'Installing FFmpeg'

    brew_install_and_cache_within_time_limit ffmpeg || { [ $? -gt 1 ] && return 2 || return 0; }

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
