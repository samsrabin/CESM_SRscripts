#!/bin/bash
set -e

upstream="ESCOMP/CTSM"
userfork="samsrabin/CTSM"

# Set up branch name and directory
today=$(date +%Y%m%d)
branchname="merge-b4bdev-${today}"
dirname="ctsm_${branchname}"

# Clone
git clone --origin upstream git@github.com:${upstream}.git "${dirname}"
cd "${dirname}"

# Get reference to merge. Use tag if latest master commit has one.
set +e
ref_to_merge=$(git describe --exact-match)
set -e
if [[ "${ref_to_merge}" == "" ]]; then
    ref_to_merge="master"
fi

# Create merge branch and merge into it
git checkout b4b-dev
git checkout -b "${branchname}"
git merge --no-edit --no-ff ${ref_to_merge}

# Push merge branch to user's fork
git remote add fork git@github.com:${userfork}.git
git push fork "${branchname}"

echo "Ready for testing in ${dirname}"

exit 0
