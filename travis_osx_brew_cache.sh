# Library to cache locally-built Homebrew bottles between macOS CI runs.
#
# Packages are installed one by one, dependencies first.
# If Homebrew has a bottle for the current OS, it is used.
# If not, the package is built with `--build-bottle`, and the resulting bottle
#  is saved into $BREW_LOCAL_BOTTLE_DIR to be installed from there in the next runs.
# $BREW_LOCAL_BOTTLE_DIR is supposed to be saved and restored by CI cache.
#
# Homebrew installs core formulae from its JSON API, so there are no formula files to add
#  bottle blocks to. Cached bottles are installed directly from files instead.
#
# If building takes too long, the build goes into "bootstrap mode": the rest of the build is skipped
#  and the job fails, but the cache is still saved. The next run continues from where this one stopped.


#Should be in CI cache
BREW_LOCAL_BOTTLE_DIR="${BREW_LOCAL_BOTTLE_DIR:-$HOME/local_bottle_metadata}"
mkdir -p "$BREW_LOCAL_BOTTLE_DIR"

# Starting reference point for elapsed build time; seconds since the epoch.
BREW_TIME_START=${BREW_TIME_START:-$(date +%s)}

# If after a package is built, elapsed time is more than this many seconds, go into bootstrap mode.
# GitHub-hosted runners limit a job to 6 hours. The cutoff should leave enough time
#  to build the main project and save the cache.
BREW_TIME_LIMIT=${BREW_TIME_LIMIT:-$((240*60))}
# If a slow-building package is about to be built and the projected build end moment is beyond this many seconds,
# skip that build and go into bootstrap mode.
# This cutoff should leave enough time for cache save.
BREW_TIME_HARD_LIMIT=${BREW_TIME_HARD_LIMIT:-$((300*60))}


# Auto cleanup can delete installed old versions of packages
export HOMEBREW_NO_INSTALL_CLEANUP=1
# Don't upgrade or rebuild preinstalled packages that depend on what we install
export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_ENV_HINTS=1

# Don't query analytical info online on `brew info`,
#  this takes several seconds and we don't need it
# see https://docs.brew.sh/Manpage , "info formula" section
export HOMEBREW_NO_GITHUB_API=1

#Packages already installed in the current session to avoid checking them again
_BREW_ALREADY_INSTALLED='$'     #$ = illegal package name; a blank line would cause macos grep to swallow everything

#Cached bottles that are valid for the current formulae, "<package> <bottle path>" lines
_BREW_LOCAL_BOTTLES='$'


#Public functions

function brew_install_and_cache_within_time_limit {
    # Install the package and its dependencies one by one;
    # use bottle if available, build and cache bottle if not.
    # Terminate and exit with status 1 if this takes too long.
    # Exit with status 2 on any other error.
    _brew_install_and_cache_within_time_limit $@ \
    || if test $? -eq 1; then brew_go_bootstrap_mode; return 1; else return 2; fi
}

function brew_add_local_bottles {
    # Should be called at startup, after the cache is restored.
    # Registers cached locally-built bottles so that they are installed instead of building.
    # If the package was updated, removes the obsolete bottle.

    echo "Cached bottles:"
    ls "$BREW_LOCAL_BOTTLE_DIR"

    for JSON in "$BREW_LOCAL_BOTTLE_DIR"/*.json; do
        [ -e "$JSON" ] || break
        local PACKAGE JSON_VERSION BOTTLE_FILE BOTTLE_HASH
        _brew_parse_bottle_json "$JSON" PACKAGE JSON_VERSION BOTTLE_FILE BOTTLE_HASH

        local BOTTLE; BOTTLE="$BREW_LOCAL_BOTTLE_DIR/$BOTTLE_FILE"
        echo "Local bottle: $PACKAGE $JSON_VERSION"

        local FORMULA_VERSION=""
        _brew_parse_package_info "$PACKAGE" FORMULA_VERSION || true

        if [ "$FORMULA_VERSION" != "$JSON_VERSION" ]; then
            echo "The cached bottle is obsolete: formula ${FORMULA_VERSION:-is not available}"
        elif [ ! -f "$BOTTLE" ]; then
            echo "Cached bottle file is missing!" >&2
        elif [ "$(shasum -a 256 "$BOTTLE" | cut -d' ' -f1)" != "$BOTTLE_HASH" ]; then
            echo "Cached bottle file is corrupted!" >&2
        else
            _BREW_LOCAL_BOTTLES="$_BREW_LOCAL_BOTTLES"$'\n'"$PACKAGE $BOTTLE"
            continue
        fi

        echo "Deleting the cached bottle and its metadata"
        rm -f "$BOTTLE" "$JSON"
    done

    brew_cache_cleanup
}

function brew_cache_cleanup {
    # Remove bottle files left without metadata, e.g. after a failure
    local BOTTLE
    for BOTTLE in "$BREW_LOCAL_BOTTLE_DIR"/*.tar.gz; do
        [ -e "$BOTTLE" ] || break
        if ! grep -qF " $BOTTLE" <<<"$_BREW_LOCAL_BOTTLES"; then
            echo "Removing stray file: $(basename "$BOTTLE")"
            rm -f "$BOTTLE"
        fi
    done
}


function brew_go_bootstrap_mode {
# Can be overridden
# Make the rest of the build be skipped. The CI job is expected to save the cache anyway.
    local EXIT_CODE=${1:-1}

    echo "Going into cache bootstrap mode"

    BREW_BOOTSTRAP_MODE=1

    if [ "$EXIT_CODE" -ne 0 ]; then
        echo '::warning::Building dependencies took too long. Re-run the job to continue from cache.'
    fi
}



#Internal functions

function _brew_install_and_cache_within_time_limit {
    # This fn is run with || so errexit can't be enabled

    local PACKAGE TIME_LIMIT TIME_HARD_LIMIT TIME_START MARKED_INSTALLED
    PACKAGE="${1:?}" || return 2
    TIME_LIMIT=${2:-$BREW_TIME_LIMIT} || return 2
    TIME_HARD_LIMIT=${3:-$BREW_TIME_HARD_LIMIT} || return 2
    TIME_START=${4:-$BREW_TIME_START} || return 2

    if grep -qxFf <(cat <<<"$_BREW_ALREADY_INSTALLED") <<<"$PACKAGE"; then
        MARKED_INSTALLED=1
    fi

    # Not piping `brew outdated` directly into `grep -q`: brew fails with "Broken pipe" when grep exits early
    if [ -n "$MARKED_INSTALLED" ] || (brew list --versions "$PACKAGE" >/dev/null && ! grep -qxF "${PACKAGE##*/}" <<<"$(brew outdated --formula --quiet)"); then
        echo "Already installed and the latest version: $PACKAGE"
        if [ -z "$MARKED_INSTALLED" ]; then _brew_mark_installed "$PACKAGE"; fi
        return 0
    fi

    local BUILD_FROM_SOURCE INCLUDE_BUILD KEG_ONLY

    _brew_is_bottle_available "$PACKAGE" KEG_ONLY || BUILD_FROM_SOURCE=1
    [ -n "$BUILD_FROM_SOURCE" ] && INCLUDE_BUILD="--include-build" || true

    # Whitespace is illegal in package names so converting all whitespace into single spaces due to no quotes is okay.
    DEPS=`brew deps "$PACKAGE" $INCLUDE_BUILD` || return 2
    DEPS=`grep -vxF <(cat <<<"$_BREW_ALREADY_INSTALLED") <<<"$DEPS"` || test $? -eq 1 || return 2
    for dep in $DEPS; do
        #TIME_LIMIT only has to be met if we'll be actually building the main project this iteration, i.e. after the "root" module installation
        #While we don't know that yet, we can make better use of the given time with a laxer limit
        #We still can't overrun TIME_HARD_LIMIT as that wouldn't leave time to save the cache
        _brew_install_and_cache_within_time_limit "$dep" $(((TIME_LIMIT+TIME_HARD_LIMIT)/2)) "$TIME_HARD_LIMIT" "$TIME_START" || return $?
    done

    if [ -n "$BUILD_FROM_SOURCE" ]; then
        _brew_check_slow_building_ahead "$PACKAGE" "$TIME_START" "$TIME_HARD_LIMIT" || return $?
    fi
    _brew_install_and_cache "$PACKAGE" "$([[ -z "$BUILD_FROM_SOURCE" ]] && echo 1 || echo 0)" "$KEG_ONLY" || return 2
    _brew_check_elapsed_build_time "$TIME_START" "$TIME_LIMIT" || return $?
}

function _brew_parse_bottle_json {
    # Parse JSON file resulting from `brew bottle --json`
    # and save data into specified variables

    local JSON; JSON="${1:?}"; shift

    local JSON_DATA; JSON_DATA=$(python3 -c 'if True:
    import sys,json; j=json.load(open(sys.argv[1],"rb")); [name]=j.keys(); [pdata]=j.values()
    print(name)
    print(pdata["formula"]["pkg_version"])
    [tag_dict]=pdata["bottle"]["tags"].values()
    print(tag_dict["local_filename"])
    print(tag_dict["sha256"])
    ' "$JSON")

    unset JSON

    { local i v; for i in {1..4}; do
        read -r v
        eval "${1:?}=\"$v\""
        shift
    done } <<< "$JSON_DATA"
}

function _brew_parse_package_info {
    # Get the current version of a package from `brew info --json`
    # and save it into the specified variable

    local PACKAGE; PACKAGE="${1:?}"; shift

    local VERSION; VERSION=$(brew info --json=v2 "$PACKAGE" | python3 -c 'if True:
    import sys, json; data=json.load(sys.stdin)["formulae"][0]
    revision=data["revision"]
    # in bottle''s json, revision is included into version; here, they are separate
    print(data["versions"]["stable"]+("_"+str(revision) if revision else ""))
    ') || return 1

    eval "${1:?}=\"$VERSION\""
}

function _brew_local_bottle {
    # Print the path of a cached bottle for the package, if any
    awk -v p="${1:?}" '$1==p {print $2; exit}' <<<"$_BREW_LOCAL_BOTTLES"
}


function _brew_is_bottle_available {

    local PACKAGE;PACKAGE="${1:?}"
    local VAR_KEG_ONLY="$2"

    # `brew info` prints "Error: Broken pipe" if piped to `head` and the info is long
    local INFO;INFO="$(brew info "$PACKAGE")"; INFO="$(head -n 1 <<<"$INFO")"
    if [ -n "$VAR_KEG_ONLY" ]; then
        if grep -qwF '[keg-only]' <<<"$INFO"; then
            eval "${VAR_KEG_ONLY}=1"
        else
            eval "${VAR_KEG_ONLY}=0"
        fi
    fi

    if [ -n "$(_brew_local_bottle "$PACKAGE")" ]; then
        echo "Local bottle available: $INFO"
        return 0
    fi

    if grep -qwF '(bottled)' <<<"$INFO"; then
        echo "Bottle available: $INFO"
        return 0
    else
        echo "Bottle not available: $INFO"
        return 1
    fi
}

function _brew_install_and_cache {
    # Install bottle or make and cache bottle.
    # assumes that deps were already installed
    # and not already the latest version
    # Is run with || so errexit is off: every step has to be checked explicitly

    local PACKAGE USE_BOTTLE KEG_ONLY
    PACKAGE="${1:?}"
    USE_BOTTLE="${2:?}"
    KEG_ONLY="${3:?}"
    local VERB LOCAL_BOTTLE

    if brew list --versions "$PACKAGE"; then
        # Install alongside the old version to avoid to have to update "runtime dependents"
        # https://discourse.brew.sh/t/can-i-install-a-new-version-without-having-to-upgrade-runtime-dependents/4443
        VERB="install --force"
        if [ "$KEG_ONLY" -eq 0 ]; then
            brew unlink "$PACKAGE" || return 1
        fi
    else
        VERB=install
    fi

    LOCAL_BOTTLE="$(_brew_local_bottle "$PACKAGE")"

    if [ -n "$LOCAL_BOTTLE" ]; then
        echo "Installing local bottle for: $PACKAGE"
        brew $VERB "$LOCAL_BOTTLE" || _brew_check_postinstall_failure "$PACKAGE" || return 1
    elif [[ "$USE_BOTTLE" -gt 0 ]]; then
        echo "Installing bottle for: $PACKAGE"
        brew $VERB "$PACKAGE" || _brew_check_postinstall_failure "$PACKAGE" || return 1
    else
        echo "Building bottle for: $PACKAGE"
        brew $VERB --build-bottle "$PACKAGE" || _brew_check_postinstall_failure "$PACKAGE" || return 1

        # `brew bottle` puts the files into the current directory
        local WORK_DIR; WORK_DIR=$(mktemp -d)
        exec 3>&1
        # --no-rebuild: don't look up already published bottles to determine the rebuild number
        local OUT=$(cd "$WORK_DIR" && brew bottle --json --no-rebuild "$PACKAGE" | tee /dev/fd/3)
        exec 3>&-

        # doesn't seem to be a documented way to get file names
        local BOTTLE; BOTTLE="$WORK_DIR/$(grep -Ee '^\./' <<<"$OUT" | head -n 1)"
        local JSON; JSON=$(sed -E 's/bottle(.[[:digit:]]+)?\.tar\.gz$/bottle.json/' <<<"$BOTTLE")
        test -f "$JSON" -a -f "$BOTTLE" || return 1

        #proper procedure as per https://discourse.brew.sh/t/how-are-bottle-and-postinstall-related-is-it-safe-to-run-bottle-after-postinstall/3410/4
        brew uninstall --ignore-dependencies "$PACKAGE" || return 1
        brew $VERB "$BOTTLE" || _brew_check_postinstall_failure "$PACKAGE" || return 1

        # The file name in the JSON is what the bottle is going to be found by
        local BOTTLE_FILE; _brew_parse_bottle_json "$JSON" _ _ BOTTLE_FILE _
        mv "$BOTTLE" "$BREW_LOCAL_BOTTLE_DIR/$BOTTLE_FILE" || return 1
        mv "$JSON" "$BREW_LOCAL_BOTTLE_DIR/" || return 1
        rm -rf "$WORK_DIR"
        _BREW_LOCAL_BOTTLES="$_BREW_LOCAL_BOTTLES"$'\n'"$PACKAGE $BREW_LOCAL_BOTTLE_DIR/$BOTTLE_FILE"
    fi

    _brew_mark_installed "$PACKAGE"
}

function _brew_check_postinstall_failure {
    # `brew install` fails also if only the post-install step failed
    #  (seen with ca-certificates on Intel, which Homebrew doesn't support any more).
    # If the current version did get installed, retry the step once and carry on anyway.

    local PACKAGE VERSION
    PACKAGE="${1:?}"
    _brew_parse_package_info "$PACKAGE" VERSION || return 1
    grep -qwF -- "$VERSION" <<<"$(brew list --versions "$PACKAGE")" || return 1

    brew postinstall "$PACKAGE" && return 0
    echo "::warning::Post-install step of $PACKAGE failed, continuing anyway"
}

function _brew_mark_installed {
    _BREW_ALREADY_INSTALLED="$_BREW_ALREADY_INSTALLED"$'\n'"${1:?}"
}

function _brew_check_elapsed_build_time {
    # If time limit has been reached,
    # arrange for further build to be skipped and return 1

    local TIME_START TIME_LIMIT ELAPSED_TIME
    TIME_START="${1:?}"
    TIME_LIMIT="${2:?}"

    ELAPSED_TIME=$(($(date +%s) - $TIME_START))
    echo "Elapsed time: "$(($ELAPSED_TIME/60))"m (${ELAPSED_TIME}s)"

    if [[ "$ELAPSED_TIME" -gt $TIME_LIMIT ]]; then
        brew_go_bootstrap_mode
        return 1
    fi
    return 0
}

function _brew_check_slow_building_ahead {

    #If the package's projected build completion is higher than hard limit,
    # skip it and arrange for further build to be skipped and return 1

    local PACKAGE TIME_START TIME_HARD_LIMIT
    PACKAGE="${1:?}"
    TIME_START="${2:?}"
    TIME_HARD_LIMIT="${3:?}"

    local PROJECTED_BUILD_TIME
    PROJECTED_BUILD_TIME=$(echo "$BREW_SLOW_BUILIDING_PACKAGES" | awk '$1=="'"$PACKAGE"'"{print $2}')
    [ -z "$PROJECTED_BUILD_TIME" ] && return 0 || true

    local PROJECTED_BUILD_END_ELAPSED_TIME
    PROJECTED_BUILD_END_ELAPSED_TIME=$(( $(date +%s) - TIME_START + PROJECTED_BUILD_TIME * 60))

    if [[ "$PROJECTED_BUILD_END_ELAPSED_TIME" -ge "$TIME_HARD_LIMIT" ]]; then
        echo -e "\nProjected build end elapsed time for $PACKAGE: $((PROJECTED_BUILD_END_ELAPSED_TIME/60))m (${PROJECTED_BUILD_END_ELAPSED_TIME}s)"
        brew_go_bootstrap_mode
        return 1
    fi
    return 0
}
