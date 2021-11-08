# Library to cache downloaded and locally-built Homebrew bottles in Travis OSX build.


#Should be in Travis' cache
BREW_LOCAL_BOTTLE_METADATA="$HOME/local_bottle_metadata"

#FIXME: temporary fix to enable the build, should be replaced with the proper path to the cache dir
mkdir -p $BREW_LOCAL_BOTTLE_METADATA

# Starting reference point for elapsed build time; seconds since the epoch.
#TRAVIS_TIMER_START_TIME is set at the start of a log fold, in nanoseconds since the epoch
BREW_TIME_START=$(($TRAVIS_TIMER_START_TIME/10**9))

# If after a package is built, elapsed time is more than this many seconds, fail the build but save Travis cache
# The cutoff moment should leave enough time till Travis' job time limit to process the main project.
#  Since we have moved deps into a separate stage, we don't need to leave time for the project any more
BREW_TIME_LIMIT=$((42*60))
# If a slow-building package is about to be built and the projected build end moment is beyond this many seconds,
# skip that build, fail the Travis job and save Travis cache.
# This cutoff should leave enough time for before_cache and cache save.
BREW_TIME_HARD_LIMIT=$((43*60))


# Auto cleanup can delete locally-built bottles
# when the caching logic isn't prepared for that
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Don't query analytical info online on `brew info`,
#  this takes several seconds and we don't need it
# see https://docs.brew.sh/Manpage , "info formula" section
export HOMEBREW_NO_GITHUB_API=1

#Packages already installed in the current session to avoid checking them again
_BREW_ALREADY_INSTALLED='$'     #$ = illegal package name; a blank line would cause macos grep to swallow everything


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
    # Should be called after `brew update` at startup.
    # Adds metadata for cached locally-built bottles to local formulas
    #  so that `brew` commands can find them.
    # If the package was updated, removes the corresponding files
    #  and the bottle's entry in the formula, if any.

    # Bottle entry in formula:
    #   bottle do
    #     <...>
    #     sha256 "<sha256>" => :<os_codename>
    #     <...>
    #   end

    echo "Cached bottles:"
    ls "$(brew --cache)/downloads" || true  #may not exist initially since it's "$(brew --cache)" that is in Travis cache
    echo "Saved .json's and links:"
    ls "$BREW_LOCAL_BOTTLE_METADATA"

    for JSON in "$BREW_LOCAL_BOTTLE_METADATA"/*.json; do
        [ -e "$JSON" ] || break    # OSX 10.11 bash has no nullglob
        local PACKAGE JSON_VERSION JSON_REBUILD OS_CODENAME BOTTLE_HASH

        _brew_parse_bottle_json "$JSON" PACKAGE JSON_VERSION JSON_REBUILD OS_CODENAME BOTTLE_HASH

        echo "Adding local bottle: $PACKAGE ${JSON_VERSION}_${JSON_REBUILD}"

        local FORMULA_VERSION FORMULA_REBUILD FORMULA_BOTTLE_HASH

        _brew_parse_package_info "$PACKAGE" "$OS_CODENAME" FORMULA_VERSION FORMULA_REBUILD FORMULA_BOTTLE_HASH

        local FORMULA_HAS_BOTTLE; [ -n "$FORMULA_BOTTLE_HASH" ] && FORMULA_HAS_BOTTLE=1 || true


        local BOTTLE_LINK BOTTLE=""; BOTTLE_LINK="${JSON}.bottle.lnk";
        local BOTTLE_EXISTS= BOTTLE_MISMATCH= VERSION_MISMATCH=


        # Check that the bottle file exists and is still appropriate for the formula
        if [[ "$FORMULA_VERSION" != "$JSON_VERSION" || "$JSON_REBUILD" != "$FORMULA_REBUILD" ]]; then
            VERSION_MISMATCH=1;
            echo "The cached bottle is obsolete: formula ${FORMULA_VERSION}_${FORMULA_REBUILD}"
        fi
        if [ -f "$BOTTLE_LINK" ]; then
            BOTTLE=$(cat "$BOTTLE_LINK");
            BOTTLE=$(cd "$(dirname "$BOTTLE")"; pwd)/$(basename "$BOTTLE")

            if [ -e "$BOTTLE" ]; then
                BOTTLE_EXISTS=1;

                # The hash in `brew --cache $PACKAGE` entry is generated from download URL,
                #  which itself is generated from base URL and version
                # (see Homebrew/Library/Homebrew/download_strategy.rb:cached_location).
                # So if version changes, hashes will always mismatch anyway
                #  and we don't need a separate message about this.
                # XXX: OSX doesn't have `realpath` so can't compare the entire paths
                if [ -n "$FORMULA_HAS_BOTTLE" -a -z "$VERSION_MISMATCH" -a \
                    "$(basename "$(brew --cache "$PACKAGE")")" != "$(basename "$BOTTLE")" ]; then
                        BOTTLE_MISMATCH=1;
                        echo "Cached bottle file doesn't correspond to formula's cache entry!" \
                             "This can happen if download URL has changed." >&2
                fi
            else
                echo "Cached bottle file is missing!" >&2
            fi
        else
            echo "Link file is missing or of invalid type!" >&2
        fi

        # Delete cached bottle and all metadata if invalid
        if [[ -z "$BOTTLE_EXISTS" || -n "$VERSION_MISMATCH" || -n "$BOTTLE_MISMATCH" ]]; then
            echo "Deleting the cached bottle and all metadata"

            if [ "$FORMULA_BOTTLE_HASH" == "$BOTTLE_HASH" ]; then
                echo "A bottle block for the cached bottle was merged into the updated formula. Removing..."
                local FORMULA; FORMULA=$(brew formula "$PACKAGE")
                perl -wpe 'BEGIN { our $IN_BLOCK=0; }
                    if ( ($IN_BLOCK==0) && /^\s*bottle\s+do\s*$/ ) { $IN_BLOCK=1; next; }
                    if ( ($IN_BLOCK==1) && /^\s*end\s*$/ )         { $IN_BLOCK=-1; next; }
                    if ( ($IN_BLOCK==1) && /^\s*sha256\s+"(\w+)"\s+=>\s+:\w+\s*$/ )
                                                 { if ( $1 eq "'"$BOTTLE_HASH"'" ) {$_="";}; next; }
                '  <"$FORMULA" >"${FORMULA}.new"
                # Depending on diff version, 1 may mean differences found
                # https://stackoverflow.com/questions/6971284/what-are-the-error-exit-values-for-diff
                diff -u "$FORMULA" "${FORMULA}.new" || test $? -le 1
                (   cd $(dirname "$FORMULA")
                    FORMULA=$(basename "$FORMULA")
                    mv -v "${FORMULA}.new" "$FORMULA"
                    git commit -m "Removed obsolete local bottle ${JSON_VERSION}_${JSON_REBUILD} :${OS_CODENAME}" "$FORMULA"
                )
            fi

            if [ -n "$BOTTLE" -a -n "$BOTTLE_EXISTS" ]; then rm "$BOTTLE"; fi
            rm -f "$BOTTLE_LINK"
            rm "$JSON"

        #(Re)add metadata to the formula otherwise
        else
            if [ "$FORMULA_BOTTLE_HASH" == "$BOTTLE_HASH" ]; then
                echo "The cached bottle is already present in the formula"
            else
                brew bottle --merge --write "$JSON"
            fi
        fi
    done
}


function brew_cache_cleanup {
    #Cleanup caching directories
    # Is supposed to be called in before_cache

    #Lefovers from some failure probably
    rm -f "$BREW_LOCAL_BOTTLE_METADATA"/*.tar.gz

    #`brew cleanup` may delete locally-built bottles that weren't needed this time
    # so we're saving and restoring them
    local BOTTLE_LINK BOTTLE
    for BOTTLE_LINK in "$BREW_LOCAL_BOTTLE_METADATA"/*.lnk; do
        [ -e "$BOTTLE_LINK" ] || break
        BOTTLE=$(cat "$BOTTLE_LINK")
        ln "$BOTTLE" "$BREW_LOCAL_BOTTLE_METADATA/"
    done
    brew cleanup
    local BOTTLE_BASENAME
    for BOTTLE_LINK in "$BREW_LOCAL_BOTTLE_METADATA"/*.lnk; do
        [ -e "$BOTTLE_LINK" ] || break
        BOTTLE=$(cat "$BOTTLE_LINK")
        BOTTLE_BASENAME=$(basename "$BOTTLE")
        if test ! -e "$BOTTLE"; then
            echo "Restoring: $BOTTLE_BASENAME"
            mv "$BREW_LOCAL_BOTTLE_METADATA/$BOTTLE_BASENAME" "$BOTTLE"
        else
            rm "$BREW_LOCAL_BOTTLE_METADATA/$BOTTLE_BASENAME"
        fi
    done
}


function brew_go_bootstrap_mode {
# Can be overridden
# Terminate the build but ensure saving the cache
    local EXIT_CODE=${1:-1}

    echo "Going into cache bootstrap mode"

    BREW_BOOTSTRAP_MODE=1

    #Can't just `exit` because that would terminate the build without saving the cache
    #Have to replace further actions with no-ops

    local MESSAGE=""; if [ "$EXIT_CODE" -ne 0 ]; then
        MESSAGE='Building dependencies took too long. Restart the build in Travis UI to continue from cache.';
    fi

    eval '
    function '"$cmd"' { return 0; }
    function repair_wheelhouse { return 0; }
    function install_run {'\
        "$(if [ -n "$MESSAGE" ]; then
            echo \
        '        echo -e "\n'"$MESSAGE"'\n"'
        fi)"\
    '
        # Travis runs user scripts via `eval` i.e. in the same shell process.
        # So have to unset errexit in order to get to cache save stage
        set +e; return '"$EXIT_CODE"'
    }'
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

    if [ -n "$MARKED_INSTALLED" ] || (brew list --versions "$PACKAGE" >/dev/null && ! (brew outdated | grep -qxF "$PACKAGE")); then
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
        #While we don't know that yet, we can make better use of Travis-given time with a laxer limit
        #We still can't overrun TIME_HARD_LIMIT as that wouldn't leave time to save the cache
        _brew_install_and_cache_within_time_limit "$dep" $(((TIME_LIMIT+TIME_HARD_LIMIT)/2)) "$TIME_HARD_LIMIT" "$TIME_START" || return $?
    done

    _brew_check_slow_building_ahead "$PACKAGE" "$TIME_START" "$TIME_HARD_LIMIT" || return $?
    _brew_install_and_cache "$PACKAGE" "$([[ -z "$BUILD_FROM_SOURCE" ]] && echo 1 || echo 0)" "$KEG_ONLY" || return 2
    _brew_check_elapsed_build_time "$TIME_START" "$TIME_LIMIT" || return $?
}


function _brew_parse_bottle_json {
    # Parse JSON file resulting from `brew bottle --json`
    # and save data into specified variables

    local JSON; JSON="${1:?}"; shift

    local JSON_DATA; JSON_DATA=$(python2.7 -c 'if True:
    import sys,json; j=json.load(open(sys.argv[1],"rb")); [name]=j.keys(); [pdata]=j.values()
    print name
    print pdata["formula"]["pkg_version"]
    print pdata["bottle"]["rebuild"]
    [(tag_name, tag_dict)]=pdata["bottle"]["tags"].items()
    print tag_name
    print tag_dict["sha256"]
    ' "$JSON")

    unset JSON

    { local i v; for i in {1..5}; do
        read -r v
        eval "${1:?}=\"$v\""
        shift
    done } <<< "$JSON_DATA"
}

function _brew_parse_package_info {
    # Get and parse `brew info --json` about a package
    # and save data into specified variables

    local PACKAGE OS_CODENAME
    PACKAGE="${1:?}"; shift
    OS_CODENAME="${1:?}"; shift

    local JSON_DATA; JSON_DATA=$(python2.7 -c 'if True:
    import sys, json, subprocess; j=json.loads(subprocess.check_output(("brew","info","--json=v1",sys.argv[1])))
    data=j[0]
    revision=data["revision"]
    # in bottle''s json, revision is included into version; here, they are separate
    print data["versions"]["stable"]+("_"+str(revision) if revision else "")
    bottle_data=data["bottle"].get("stable",{"rebuild":"","files":{}})
    print bottle_data["rebuild"]
    print bottle_data["files"].get(sys.argv[2],{"sha256":"!?"})["sha256"]     #prevent losing trailing blank line to command substitution
    ' \
    "$PACKAGE" "$OS_CODENAME"); JSON_DATA="${JSON_DATA%\!\?}"  #!? can't occur in a hash

    unset PACKAGE OS_CODENAME

    { local i v; for i in {1..3}; do
        read -r v
        eval "${1:?}=\"$v\""
        shift
    done } <<< "$JSON_DATA"
}



function _brew_is_bottle_available {

    local PACKAGE;PACKAGE="${1:?}"
    local VAR_KEG_ONLY="$2"

    # `brew info` prints "Error: Broken pipe" if piped directly to `head` and the info is long
    # 141 = 128 + SIGPIPE
    local INFO;INFO="$((brew info "$PACKAGE" | cat || test $? -eq 141) | head -n 1)"
    if [ -n "$VAR_KEG_ONLY" ]; then
        if grep -qwF '[keg-only]' <<<"$INFO"; then
            eval "${VAR_KEG_ONLY}=1"
        else
            eval "${VAR_KEG_ONLY}=0"
        fi
    fi

    if grep -qxEe '[[:space:]]*bottle :unneeded' $(brew formula "$PACKAGE"); then
        echo "Bottle disabled: $PACKAGE"
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

    local PACKAGE USE_BOTTLE KEG_ONLY
    PACKAGE="${1:?}"
    USE_BOTTLE="${2:?}"
    KEG_ONLY="${3:?}"
    local VERB

    if brew list --versions "$PACKAGE"; then
        # Install alongside the old version to avoid to have to update "runtime dependents"
        # https://discourse.brew.sh/t/can-i-install-a-new-version-without-having-to-upgrade-runtime-dependents/4443
        VERB="install --force"
        if [ "$KEG_ONLY" -eq 0 ]; then
            brew unlink "$PACKAGE"
        fi
    else
        VERB=install
    fi

    if [[ "$USE_BOTTLE" -gt 0 ]]; then
        echo "Installing bottle for: $PACKAGE"
        brew $VERB "$PACKAGE"
    else
        echo "Building bottle for: $PACKAGE"
        brew $VERB --build-bottle "$PACKAGE"
        exec 3>&1
        local OUT=$(brew bottle --json "$PACKAGE" | tee /dev/fd/3)
        exec 3>&-

        ls "$PACKAGE"*
        # doesn't seem to be a documented way to get file names
        local BOTTLE; BOTTLE=$(grep -Ee '^./' <<<"$OUT")
        #proper procedure as per https://discourse.brew.sh/t/how-are-bottle-and-postinstall-related-is-it-safe-to-run-bottle-after-postinstall/3410/4
        brew uninstall --ignore-dependencies "$PACKAGE"
        brew $VERB "$BOTTLE"

        local JSON; JSON=$(sed -E 's/bottle(.[[:digit:]]+)?\.tar\.gz$/bottle.json/' <<<"$BOTTLE")

        #`brew bottle --merge` doesn't return nonzero on nonexisting json file
        test -f "$JSON" -a -f "$BOTTLE"

        brew bottle --merge --write "$JSON"
        local CACHED_BOTTLE; CACHED_BOTTLE="$(brew --cache "$PACKAGE")"
        mv "$BOTTLE" "$CACHED_BOTTLE";
        local CACHED_JSON; CACHED_JSON="${BREW_LOCAL_BOTTLE_METADATA}/$(basename "$JSON")"
        mv "$JSON" "$CACHED_JSON"
        #Symlinks aren't cached by Travis. Will just save paths in files then.
        local BOTTLE_LINK; BOTTLE_LINK="${CACHED_JSON}.bottle.lnk"
        echo "$CACHED_BOTTLE" >"$BOTTLE_LINK"

    fi

    _brew_mark_installed "$PACKAGE"
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
        echo -e "\nProjected build end elapsed time for $PACKAGE: $((PROJECTED_BUILD_END_ELAPSED_TIME/60))m ($PROJECTED_BUILD_END_ELAPSED_TIMEs)"
        brew_go_bootstrap_mode
        return 1
    fi
    return 0
}
