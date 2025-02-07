#!/bin/bash
set -e

server_url="https://svn-ccsm-inputdata.cgd.ucar.edu/trunk/inputdata/lnd/clm2"

files_to_check="$@"

cd /fs/cgd/csm/inputdata/lnd/clm2
for f in ${files_to_check}; do
    url=${server_url}/$f
    if curl --output /dev/null --silent --head --fail "$url"; then
        # I.e., file is on server
        continue
    fi
    echo $f
done

exit 0
