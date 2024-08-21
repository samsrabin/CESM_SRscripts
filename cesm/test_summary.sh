#!/bin/bash
set -e

#############################################################################################

script="test_summary.sh"
function usage {
    echo " "
    echo -e "usage: $script [-h|--help] [-n|--skip-nlfail] [-p|--skip-pending]\n"
}

# Set defaults
skip_pending=0
skip_nlfail=0

# Args while-loop
while [ "$1" != "" ];
do
    case $1 in

        # Print help
        -h | --help)
            usage
            exit 0
            ;;

        # Don't print NLFAIL tests
        -n | --skip-nlfail)
            skip_nlfail=1
            ;;

        # Don't print pending tests
        -p  | --skip-pending)
            skip_pending=1
            ;;

        *)
            echo "$script: illegal option $1"
            usage
            exit 1 # error
            ;;
    esac
    shift
done

#############################################################################################

tmpfile=.test_summary.$(date "+%Y%m%d%H%M%S%N")
$(get_cs.status) > ${tmpfile}

# We don't want the script to exit if grep finds no matches
set +e

# Account for completed tests
grep -E "FAIL.*BASELINE exception" ${tmpfile} | awk '{print $2}' > accounted_for_baselineException
grep -E "FAIL.*CREATE_NEWCASE" ${tmpfile} | grep -v "EXPECTED" | awk '{print $2}' > accounted_for_createCase
grep -E "FAIL.*SHAREDLIB_BUILD" ${tmpfile} | grep -v "EXPECTED" | awk '{print $2}' > accounted_for_sharedlibBuild
grep -E "FAIL.*MODEL_BUILD" ${tmpfile} | grep -v "EXPECTED" | awk '{print $2}' > accounted_for_modelBuild
grep -E "FAIL.*RUN" ${tmpfile} | grep -v "EXPECTED" | awk '{print $2}' > accounted_for_runFail
grep -E "PASS.*BASELINE" ${tmpfile} | awk '{print $2}' > accounted_for_pass
grep -E "FAIL.*COMPARE_base_rest" ${tmpfile} | grep -v "EXPECTED" | awk '{print $2}' > accounted_for_compareBaseRest
grep -E "FAIL.*COMPARE_base_modpes" ${tmpfile} | grep -v "EXPECTED" | awk '{print $2}' > accounted_for_compareBaseModpes
grep -E "FAIL.*BASELINE.*otherwise" ${tmpfile} | awk '{print $2}' > accounted_for_fieldlist
grep -E "FAIL.*BASELINE.*some baseline files were missing" ${tmpfile} | awk '{print $2}' > accounted_for_missingBaselineFiles
grep -E "FAIL.*BASELINE.*baseline directory.*does not exist" ${tmpfile} | awk '{print $2}' > accounted_for_missingBaselineDir
grep -E "EXPECTED FAILURE" ${tmpfile} | awk '{print $2}' > accounted_for_expectedFail
grep -E "FAIL.*XML*" ${tmpfile} | awk '{print $2}' > accounted_for_xmlFail

# Add a file for tests that failed in NLCOMP, even if they're also in another accounted_for file
grep -E "FAIL.*NLCOMP" ${tmpfile} | awk '{print $2}' > accounted_for_nlfail

[[ -e accounted_for_truediffs ]] && rm accounted_for_truediffs
touch accounted_for_truediffs
for e in $(grep -E "FAIL.*BASELINE.*DIFF" ${tmpfile} | awk '{print $2}'); do
    # Runs that fail because of restart diffs (can?) also show up as true baseline diffs. Only keep them as the former.
    if [[ $(grep ${e} accounted_for_compareBaseRest | wc -l) -gt 0 ]]; then
        continue
    fi
    # Some expected-fail runs complete but have diffs. Note those.
    if [[ $(grep ${e} accounted_for_expectedFail | wc -l) -gt 0 ]]; then
        echo "${e} (EXPECTED FAIL)" >> accounted_for_truediffs
        continue
    fi
    echo ${e} >> accounted_for_truediffs
done

# Account for pending tests
[[ -e accounted_for_pend ]] && rm accounted_for_pend
touch accounted_for_pend
for t in $(grep -E "Overall: PEND" ${tmpfile} | awk '{print $1}' | sort); do
    if [[ $(grep $t accounted_for_expectedFail | wc -l) -eq 0 ]]; then
        echo $t >> accounted_for_pend
    fi
done

set -e

testlist="$(grep "Overall" ${tmpfile} | awk '{print $1}')"

missing_tests=
for d in ${testlist}; do
    if [[ "$(grep $d accounted_for* | wc -l)" -eq 0 ]]; then
        missing_tests="${missing_tests} $d"
    fi
done

truly_unaccounted=""
for d in ${missing_tests}; do
    n_fail_lines=$(grep $d ${tmpfile} | grep FAIL | grep -v "UNEXPECTED: expected FAIL" | wc -l)
    if [[ ${n_fail_lines} -eq 0 ]]; then
        echo $d >> accounted_for_pass
    else
        truly_unaccounted="${truly_unaccounted} $d"
    fi
done
rm -f not_accounted_for
touch not_accounted_for
for d in ${truly_unaccounted}; do
    grep $d ${tmpfile} >> not_accounted_for
done

for f in accounted*; do
    [[ $f == accounted_for_pend ]] && continue
    [[ $f == accounted_for_nlfail && ${skip_nlfail} -eq 1 ]] && continue
    echo $f
    cat $f
    echo " "
done

# Print these last
if [[ ${skip_pending} -eq 0 ]]; then
    echo accounted_for_pend
    cat accounted_for_pend
    echo " "
fi
echo not_accounted_for
cat not_accounted_for
echo " "

rm ${tmpfile}
exit 0
