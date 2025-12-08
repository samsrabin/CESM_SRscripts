#!/bin/bash
set -e

# Required args
ctsm_dir="$1"
ctsm_baseline="$2"

if [[ "${ctsm_baseline}" == "" ]]; then
    echo "You must supply ctsm_dir and ctsm_baseline" >&2
    exit 1
fi
if [[ "$BASELINE" == "" ]]; then
    echo "Env variable BASELINE (path to CTSM baseline dir) not defined" >&2
    exit 2
fi

cd "${ctsm_dir}"

# Make sure CTSM checkout is clean and on the right version
git add . && git diff --exit-code
ctsm_tag="$(git describe)"
if [[ "${ctsm_tag}" != "${ctsm_baseline}" ]]; then
    echo "ctsm_baseline ${ctsm_baseline} but ctsm is currently at ${ctsm_tag}" >&2
    exit 3
fi

# Update git submodules
echo "Updating git submodules..."
bin/git-fleximod update 1>/dev/null
# Error if not clean
bin/git-fleximod test 1>/dev/null

# Get FATES tag and baseline
cd src/fates
fates_tag=$(git describe)
cd "${ctsm_dir}"
fates_baseline="fates-${fates_tag}-${ctsm_baseline}"
echo "Making FATES baseline ${fates_baseline}"

# FATES baseline dir should just be a softlink to the CTSM one
cd "$BASELINE"
if [[ ! -e "${fates_baseline}" ]]; then
    ln -s "${ctsm_baseline}" "${fates_baseline}"
elif [[ "$(realpath "${fates_baseline}")" != "$(realpath "${ctsm_baseline}")" ]]; then
    echo "fates_baseline dir '$PWD/${fates_baseline}' already exists and doesn't point to ctsm_baseline dir '$PWD/${ctsm_baseline}'" >&2
    exit 4
fi

# Start test
echo " "
cd "${ctsm_dir}"
if [[ "$HOSTNAME" == "derecho"* ]]; then
    conda_prefix="conda run -n ctsm_pylib"
else
    conda_prefix=""
fi
${conda_prefix} ./run_sys_tests -s fates --skip-compare --generate ${fates_baseline} --extra-create-test-args " --skip-tests-with-existing-baselines"

exit 0
