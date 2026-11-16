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
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/Qt5.15.19/lib
  export MAKEFLAGS="-j$(grep -E '^processor[[:space:]]*:' /proc/cpuinfo | wc -l)"
  CURRENT_ARCH=$(uname -m)
  if [[ $CURRENT_ARCH == 'aarch64' ]]; then
    # To avoid network issues with pypi.org on OpenCV CN machines
    #export PIP_INDEX_URL=https://pypi.org/simple
    echo "Running for linux aarch64"
  fi
fi

if [ -n "$IS_OSX" ]; then

    source travis_osx_brew_cache.sh

    FFMPEG_LGPL_FORMULA="opencv/local/ffmpeg-lgpl"

    function generate_ffmpeg_formula {
        # Make an LGPL build of FFmpeg out of the upstream formula:
        #  no GPL parts, the same set of external libraries as in Linux builds.
        local TAP="${FFMPEG_LGPL_FORMULA%/*}"
        local TAP_DIR; TAP_DIR="$(brew --repository "$TAP")"
        [ -d "$TAP_DIR" ] || brew tap-new --no-git "$TAP"
        mkdir -p "$TAP_DIR/Formula"
        # Homebrew refuses to load formulae from third-party taps otherwise
        brew trust "$TAP"

        local FF_FORMULA; FF_FORMULA=$(mktemp)
        # Formulae from the JSON API have no source on disk, so `brew cat` doesn't work for them.
        # Fetch the source for the homebrew-core revision the API data is from.
        local FF_SOURCE_URL FF_SOURCE_SHA256
        read -r FF_SOURCE_URL FF_SOURCE_SHA256 < <(brew info --json=v2 ffmpeg | python3 -c 'if True:
            import sys, json; data=json.load(sys.stdin)["formulae"][0]
            print("https://raw.githubusercontent.com/Homebrew/homebrew-core/%s/%s" % (data["tap_git_head"], data["ruby_source_path"]),
                  data["ruby_source_checksum"]["sha256"])
            ')
        curl -fsSL --retry 3 -o "$FF_FORMULA" "$FF_SOURCE_URL"
        if [ "$(shasum -a 256 "$FF_FORMULA" | cut -d' ' -f1)" != "$FF_SOURCE_SHA256" ]; then
            echo "Checksum mismatch for $FF_SOURCE_URL" >&2
            return 1
        fi
        local LFF_FORMULA; LFF_FORMULA="$TAP_DIR/Formula/${FFMPEG_LGPL_FORMULA##*/}.rb"

        echo "Generating custom ffmpeg formula"
        # Bottle block syntax: https://docs.brew.sh/Bottles#bottle-dsl-domain-specific-language
        perl -wpe 'BEGIN {our $bottle_block;}
            if (/^class Ffmpeg < Formula$/) {$_="class FfmpegLgpl < Formula\n"; next;}
            if (/^(\s*)license\s/) {$_=$1."license \"LGPL-2.1-or-later\"\n".$1."keg_only \"it conflicts with the GPL-licensed ffmpeg formula\"\n"; next;}
            if (!$bottle_block && /^\s*bottle do$/) { $bottle_block=1; $_=""; next; }
            if ($bottle_block) { $bottle_block=0 if /^\s*end\s*$/; $_=""; next; }
            if (/^\s*depends_on "(lame|libvmaf|opus|sdl2-compat|svt-av1|x264|x265|xz)"(\s*#.*)?$/) {$_=""; next;}
            if (/^\s*--enable-(gpl|version3|libsvtav1|libopus|libx264|libx265|libmp3lame|libvmaf)$/) {$_=""; next;}
            s/--enable-ffplay$/--disable-ffplay/;
            ' <"$FF_FORMULA" >"$LFF_FORMULA"
        diff -u "$FF_FORMULA" "$LFF_FORMULA" || test $? -le 1
        rm -f "$FF_FORMULA"

        if grep -qE -e '--enable-(gpl|nonfree|version3)$' -e 'depends_on "x26[45]"' "$LFF_FORMULA"; then
            echo "The generated ffmpeg formula still has GPL parts. Update the conversion rules!" >&2
            return 1
        fi
    }

    function install_ffmpeg_lgpl {
        # Install LGPL FFmpeg and its dependencies, building and caching what has no bottles

        # Runner images may have an outdated Homebrew,
        #  e.g. 7.0.12 can't install bottles from files
        brew update
        brew --version

        generate_ffmpeg_formula
        brew_add_local_bottles
        brew_install_and_cache_within_time_limit "$FFMPEG_LGPL_FORMULA" || return $?
        # OpenCV finds FFmpeg with pkg-config
        brew_install_and_cache_within_time_limit pkgconf || return $?

        local FF_PREFIX; FF_PREFIX="$(brew --prefix "$FFMPEG_LGPL_FORMULA")"
        local FF_LICENSE; FF_LICENSE="$("$FF_PREFIX/bin/ffmpeg" -hide_banner -L)"
        # The license text is wrapped, the phrase can be split between lines
        if ! tr -s '\n ' '  ' <<<"$FF_LICENSE" | grep -qF "GNU Lesser General Public License"; then
            echo "$FF_LICENSE"
            echo "The built FFmpeg is not LGPL!" >&2
            return 1
        fi

        # The formula is keg-only, so OpenCV has to be pointed to it
        local PC_PATH; PC_PATH="$FF_PREFIX/lib/pkgconfig:$(brew --prefix openssl@3)/lib/pkgconfig"
        export PKG_CONFIG_PATH="$PC_PATH${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
        if [ -n "$GITHUB_ENV" ]; then echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH" >>"$GITHUB_ENV"; fi
    }

fi

function pre_build {
  echo "Starting pre-build"
  set -e -o pipefail

  if [ -n "$IS_OSX" ]; then
    brew install lapack
    brew install libavif
  fi

  if [ -n "$IS_OSX" ]; then
    echo "Running for OSX"

    local CACHE_STAGE;# (echo "$TRAVIS_BUILD_STAGE_NAME" | grep -qiF "final") || CACHE_STAGE=1
    CACHE_STAGE=
    export HOMEBREW_NO_AUTO_UPDATE=1

    echo 'Installing FFmpeg'

    brew update
    install_ffmpeg_lgpl || return $?

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
