#!/usr/bin/env bash
set -eo pipefail

# Get inputs
baseline_dir="$1"
test_suite_dir="$2"

# Check inputs
if [[ "${test_suite_dir}" == "" ]]; then
    echo "Provide two positional args: baseline_dir and test_suite_dir" >&2
    exit 1
fi
set -u
if [[ ! -d "${baseline_dir}" ]]; then
    echo "baseline_dir does not exist: ${baseline_dir}" >&2
    exit 1
elif [[ ! -d "${test_suite_dir}" ]]; then
    echo "test_suite_dir does not exist: ${test_suite_dir}" >&2
    exit 1
fi

module load nccmp

function get_test_name () {
    local test_dir="$1"
    (cd "${test_dir}" && ./xmlquery TEST_ARGV | grep -oE "\-testname \S*" | cut -d" " -f2)
}

cd "${baseline_dir}"

# Handle user providing a test dir instead of a test SUITE dir
if [[ -e "${test_suite_dir}/xmlquery" ]]; then
    testlist="$(get_test_name "${test_suite_dir}")"
    test_suite_dir="$(dirname "${test_suite_dir}")"
# Otherwise, get list of tests from baseline
else
    testlist="$(ls)"
fi

for t in ${testlist}; do


#if [[ $t != "ERR_"* ]]; then
#    continue
#fi

    cd $t
    echo $t
    
    # Find this test's directory in the test suite dir
    pattern="${test_suite_dir}/${t}"
    test_dir="$(ls -d "${pattern}".* | grep -vE "\.ref[12]$")"
    n=$(echo $test_dir | wc -w)
    # No matches
    if [[ $n -eq 0 ]]; then
        echo "No matches for pattern: ${pattern}.*" >&2
        exit 1
    # Multiple matches
    elif [[ $n -gt 1 ]]; then
        # Try to figure out which matching dir is the actual test directory
        for m in ${test_dir}; do
            pushd "${m}" 1>/dev/null
            testname="$(get_test_name "${m}")"
            if [[ "${testname}" == "${t}" ]]; then
                test_dir="${m}"
                popd 1>/dev/null
                break
            fi
        done

        # Error if we couldn't figure out which matching dir is the actual test directory
        if [[ "${testname}" != "${t}" ]]; then
            echo "Multiple matches, none of which have the right TEST_ARGV -testname, for pattern: ${pattern}.*" >&2
            for m in ${test_dir}; do
                echo "   $m" >&2
            done
            exit 1
        fi
    fi

    # Loop over netCDF files in the baseline dir...
    for orig in *nc; do
        # ... if any
        if [[ "${orig}" == "*nc" ]]; then
            echo "   NO BASELINE NETCDFS"
            continue
        fi

        # Get name of equivalent file in the test dir
        test_dir_basename="$(basename ${test_dir})"
        test_filename="${test_dir_basename}.${orig}"
        set +e
        new="$(ls ${test_dir}/run/${test_filename} 2>/dev/null)"
        set -e
        n=$(echo $new | wc -w)

        # No equivalent file found
        if [[ $n -eq 0 ]]; then
            # Is there an archive dir for this test?
            test_archive="${test_suite_dir}/archive/${test_dir_basename}"
            if [[ ! -d "${test_archive}" ]]; then
                echo -e "   MISSING\t${orig}\t${test_archive}"
                continue
            fi

            # If so, look in there for our file
            set +e
            new="$(find ${test_archive} -name "${test_filename}" 2>/dev/null)"
            set -e
            n=$(echo $new | wc -w)
            if [[ $n -eq 0 ]]; then
                echo -e "   MISSARCH\t${orig}"
                continue
            elif [[ $n -ne 1 ]]; then
                echo -e "   MULTARCH\t${orig}"
                for m in ${new}; do
                    echo -e "      \t\t$m"
                done
                continue
            fi

        # Multiple equivalent files found
        elif [[ $n -ne 1 ]]; then
            echo -e "   MULTI\t${orig}"
            for m in ${new}; do
                echo -e "      \t\t$m"
            done
            continue
        fi

        # Compare
        set +e
        nccmp -dfN -C 1 -x date_written,time_written,filename "${orig}" "${new}" # 1>/dev/null
        set -e
        result=$?
        if [[ ${result} -eq 0 ]]; then
            echo -e "   MATCH\t${orig}"
        else
            echo -e "   DIFF\t${orig}"
        fi
    done

    cd ../
done

exit 0
