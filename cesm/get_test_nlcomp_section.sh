#!/bin/bash
set -e

test_dir="$1"
if [[ "${test_dir}" != "" ]]; then
    cd "${test_dir}"
fi

endpattern=" ----------"
sed -n "/NLCOMP\$/,/${endpattern}/{p;/^${endpattern}/q}" TestStatus.log

exit 0
