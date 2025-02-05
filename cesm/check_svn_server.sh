#!/bin/bash
set -e

server_url="https://svn-ccsm-inputdata.cgd.ucar.edu/trunk/inputdata/lnd/clm2"

cd /fs/cgd/csm/inputdata/lnd/clm2
for f in $(find . -type f | sort); do
    url=${server_url}/$f
    if curl --output /dev/null --silent --head --fail "$url"; then
        continue
    else
        echo $f
    fi
done

exit 0
