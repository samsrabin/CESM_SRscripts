#!/bin/bash
set -e

inputdata_parent="/fs/cgd/csm/inputdata"
server_url="https://svn-ccsm-inputdata.cgd.ucar.edu/trunk/inputdata"
files_to_check="$@"

# Check that SVN server is reachable
set +e
if [[ $(/home/samrabin/scripts/cesm/ping_svn_server.sh) ]]; then
    echo "SVN server unreachable" >&2
    exit 1
fi
set -e

for f in ${files_to_check}; do
    # Make sure file is in the input data dir
    f_abspath="$(realpath $f)"
    if [[ "${f_abspath}" != "${inputdata_parent}"* ]]; then
        echo "Skipping $f (not in ${inputdata_parent})" >&2
        continue
    fi

    f_rel="$(realpath -s --relative-to="${inputdata_parent}" $f)"
    url=${server_url}/$f_rel
    if curl --output /dev/null --silent --head --fail "$url"; then
        # I.e., file is on server
        continue
    fi
    echo $f
done

exit 0
