#!/bin/bash -ex

function usage() {
    echo "Usage: $0 [--project <shell|browser>] <workspace-dir> flags..."
    echo "flags are treated the same way as a commit message would be"
    echo "(as in, they are scanned for directives just like a try: ... line)"
}

PROJECT=shell
WORKSPACE=
while [[ $# -gt 0 ]]; do
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        usage
        exit 0
    elif [[ "$1" == "--project" ]]; then
        shift
        PROJECT="$1"
        shift
    elif [[ "$1" == "--no-tooltool" ]]; then
        shift
    elif [[ -z "$WORKSPACE" ]]; then
        WORKSPACE=$( cd "$1" && pwd )
        shift
        break
    fi
done

SCRIPT_FLAGS=$*

# Ensure all the scripts in this dir are on the path....
DIRNAME=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
PATH=$DIRNAME:$PATH

# Use GECKO_BASE_REPOSITORY as a signal for whether we are running in automation.
export AUTOMATION=${GECKO_BASE_REPOSITORY:+1}

: "${GECKO_PATH:="$DIRNAME"/../../..}"

if ! [ -d "$GECKO_PATH" ]; then
    echo "GECKO_PATH must be set to a directory containing a gecko source checkout" >&2
    exit 1
fi

# Directory to hold the (useless) object files generated by the analysis.
export MOZ_OBJDIR="$WORKSPACE/obj-analyzed"
mkdir -p "$MOZ_OBJDIR"

export NO_MERCURIAL_SETUP_CHECK=1

if [[ "$PROJECT" = "browser" ]]; then (
    cd "$WORKSPACE"
    set "$WORKSPACE"
    # Mozbuild config:
    export MOZBUILD_STATE_PATH=$WORKSPACE/mozbuild/
    # Create .mozbuild so mach doesn't complain about this
    mkdir -p "$MOZBUILD_STATE_PATH"
) fi
. hazard-analysis.sh

build_js_shell
analysis_self_test

# Artifacts folder is outside of the cache.
mkdir -p "$HOME"/artifacts/ || true

function onexit () {
    grab_artifacts "$WORKSPACE/analysis" "$HOME/artifacts"
}

trap onexit EXIT

configure_analysis "$WORKSPACE/analysis"
run_analysis "$WORKSPACE/analysis" "$PROJECT"

check_hazards "$WORKSPACE/analysis"

################################### script end ###################################
