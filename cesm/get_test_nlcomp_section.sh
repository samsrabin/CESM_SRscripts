#!/bin/bash
set -e

test_dir="$1"
if [[ "${test_dir}" != "" ]]; then
    if [[ ! -d "${test_dir}" ]]; then
        cmd="ls -d ${test_dir}*"
        nfound=$(${cmd} 2>/dev/null | wc -l)
        if [[ ${nfound} -eq 0 ]]; then
            echo "Error: No directory found matching ${test_dir}*" >&2
            exit 1
        elif [[ ${nfound} -gt 1 ]]; then
            echo "Error: Multiple matches for ${test_dir}*" >&2
            exit 1
        fi
        test_dir=$(${cmd})
    fi
    cd "${test_dir}"
fi

function search_TestStatus {
    endpattern="----------"
    sed -n "/NLCOMP\$/,/${endpattern}/{p;/${endpattern}/q}" TestStatus.log
    set +e
    grep -A 999 "build-namelist failed" TestStatus.log
    set -e
}

if [[ -e TestStatus.log ]]; then
    search_TestStatus
elif [[ -e cs.status ]]; then
    if [[ -e "accounted_for_nlfail" || -e "accounted_for_nlbuildfail" ]]; then
        failing_tests=""
        if [[ -e "accounted_for_nlfail" ]]; then
            failing_tests="${failing_tests} $(cat accounted_for_nlfail)"
        fi
        if [[ -e "accounted_for_nlbuildfail" ]]; then
            failing_tests="${failing_tests} $(cat accounted_for_nlbuildfail)"
        fi
    else
        failing_tests="$(./cs.status | grep -oE "FAIL\s.*\sNLCOMP" | cut -d" " -f2)"
    fi
    for t in ${failing_tests}; do
        echo $t
        get_test_nlcomp_section.sh ${t}*
        echo " "
        echo " "
    done
else
    echo "Neither TestStatus.log nor cs.status found in $PWD" >&2
    exit 1
fi

exit 0
