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
    # add osx deployment target so it doesn't default to 10.6
    local abs_wheelhouse=$1
    # install all required packages in pyproject.toml, because bdist_wheel does not do it
    python${PYTHON_VERSION} -m pip install toml && python${PYTHON_VERSION} -c 'import toml; c = toml.load("pyproject.toml"); print("\n".join(c["build-system"]["requires"]))' | python${PYTHON_VERSION} -m pip install -r /dev/stdin
    CI_BUILD=1 python${PYTHON_VERSION} setup.py bdist_wheel --py-limited-api=cp37 -v
    cp dist/*.whl $abs_wheelhouse
    if [ -z "$IS_OSX" ]; then
      # this path can be changed in the latest manylinux image
      TOOLS_PATH=/opt/_internal/pipx/venvs/auditwheel
      /opt/python/cp39-cp39/bin/python -m venv $TOOLS_PATH
      source $TOOLS_PATH/bin/activate
      python patch_auditwheel_whitelist.py
      deactivate
    fi
    if [ -n "$USE_CCACHE" -a -z "$BREW_BOOTSTRAP_MODE" ]; then ccache -s; fi
}

if [ -n "$IS_OSX" ]; then
  echo "    > OSX environment "
  export MAKEFLAGS="-j$(sysctl -n hw.ncpu)"
else
  echo "    > Linux environment "
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/Qt5.15.0/lib
  export MAKEFLAGS="-j$(grep -E '^processor[[:space:]]*:' /proc/cpuinfo | wc -l)"
  CURRENT_ARCH=$(uname -m)
  if [[ $CURRENT_ARCH == 'aarch64' ]]; then
    # To avoid network issues with pypi.org on OpenCV CN machines
    export PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
    echo "Running for linux aarch64"
  fi
fi

if [ -n "$IS_OSX" ]; then

    source travis_osx_brew_cache.sh

    BREW_SLOW_BUILIDING_PACKAGES=$(printf '%s\n' \
        "cmake 15" \
        "ffmpeg 10" \
    )

    function generate_ffmpeg_formula {
        local FF="ffmpeg"
        local LFF="ffmpeg"
        local FF_FORMULA; FF_FORMULA=$(brew formula "${FF}")
        local LFF_FORMULA; LFF_FORMULA="$(dirname "$FF_FORMULA")/${LFF}.rb"

        local REGENERATE
        if [ -f "$LFF_FORMULA" ]; then
            local UPSTREAM_VERSION VERSION
            _brew_parse_package_info "$FF" " " UPSTREAM_VERSION _ _
            _brew_parse_package_info "$LFF" " " VERSION _ _   || REGENERATE=1
            #`rebuild` clause is ignored on `brew bottle` and deleted
            # from newly-generated formula on `brew bottle --merge` for some reason
            # so can't compare rebuild numbers
            if [ "$UPSTREAM_VERSION" != "$VERSION" ]; then
                REGENERATE=1
            fi
        else
            REGENERATE=1
        fi
        if [ -n "$REGENERATE" ]; then
            echo "Regenerating custom ffmpeg formula"
            # Bottle block syntax: https://docs.brew.sh/Bottles#bottle-dsl-domain-specific-language
            perl -wpe 'BEGIN {our ($found_blank, $bottle_block);}
                if (/(^class )(Ffmpeg)(\s.*)/) {$_=$1."Opencv".$3."\n"; next;}
                if (!$found_blank && /^$/) {$_.="conflicts_with \"ffmpeg\"\n\n"; $found_blank=1; next;}
                if (!$bottle_block && /^\s*bottle do$/) { $bottle_block=1; next; }
                if ($bottle_block) { if (/^\s*end\s*$/) { $bottle_block=0} elsif (/^\s*sha256\s/) {$_=""} next; }
if (/^\s*depends_on "(x264|x265|xvid|frei0r|rubberband|libvidstab)"$/) {$_=""; next;}
                if (/^\s*--enable-(gpl|libx264|libx265|libxvid|frei0r|librubberband|libvidstab)$/) {$_=""; next;}
                ' <"$FF_FORMULA" >"$LFF_FORMULA"
            diff -u "$FF_FORMULA" "$LFF_FORMULA" || test $? -le 1

            (   cd "$(dirname "$LFF_FORMULA")"
                # This is the official way to add a formula
                # https://docs.brew.sh/Formula-Cookbook#commit
                git add "$(basename "$LFF_FORMULA")"
                git commit -m "add/update custom ffmpeg ${VERSION}"
            )
        fi
    }

fi

function pre_build {
  echo "Starting pre-build"
  set -e -o pipefail

  if [ -n "$IS_OSX" ]; then
    brew install lapack
  fi

  if [ -n "$IS_OSX" ]; then
    echo "Running for OSX"

    local CACHE_STAGE;# (echo "$TRAVIS_BUILD_STAGE_NAME" | grep -qiF "final") || CACHE_STAGE=1
    CACHE_STAGE=
    export HOMEBREW_NO_AUTO_UPDATE=1

    echo 'Installing FFmpeg'

    brew update
    generate_ffmpeg_formula
    brew_add_local_bottles
    brew install --build-bottle ffmpeg
    # It needs when we use not the latest ffmpeg formula
    brew link ffmpeg

    if [ -n "$CACHE_STAGE" ]; then
        brew_go_bootstrap_mode 0
        return 0
    fi

    # Have to install macpython late to avoid conflict with Homebrew Python update
    before_install

  else
    echo "Running for linux"
  fi
}

function run_tests {
    # Runs tests on installed distribution from an empty directory
    echo "Run tests..."
    echo $PWD

    PYTHON=python$PYTHON_VERSION

    echo "Running for linux"

    if [ $PYTHON == "python3.7" ]; then
      $PYTHON -m pip install -U numpy==1.19.4
    fi
    cd /io/tests
    $PYTHON get_build_info.py

    cd /io/opencv
    export OPENCV_TEST_DATA_PATH=/io/opencv_extra/testdata

    test_wheels
    pylint_test
}

function test_wheels {

    echo "Starting OpenCV tests..."

    #Test package
    $PYTHON modules/python/test/test.py -v --repo .
}

function pylint_test {

    echo "Starting Pylint tests..."

    $PYTHON -m pip install pylint==2.15.9
    cd /io/tests
    $PYTHON -m pylint /io/opencv/samples/python/squares.py
}

export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x
