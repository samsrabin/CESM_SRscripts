#!/bin/bash
set -e

script="$(get_cs.status)"

tmpfile=.test_summary.$(date "+%Y%m%d%H%M%S%N")
${script} > ${tmpfile}

# We don't want the script to exit if grep finds no matches
set +e

# Account for completed tests
grep -E "FAIL.*BASELINE.*DIFF" ${tmpfile} | awk '{print $2}' > accounted_for_truediffs
grep -E "FAIL.*BASELINE exception" ${tmpfile} | awk '{print $2}' > accounted_for_baselineException
grep -E "FAIL.*SHAREDLIB_BUILD" ${tmpfile} | awk '{print $2}' > accounted_for_sharedlibBuild
grep -E "FAIL.*MODEL_BUILD" ${tmpfile} | awk '{print $2}' > accounted_for_modelBuild
grep -E "FAIL.*RUN" ${tmpfile} | grep -v "EXPECTED" | awk '{print $2}' > accounted_for_runFail
grep -E "PASS.*BASELINE" ${tmpfile} | awk '{print $2}' > accounted_for_pass
grep -E "FAIL.*BASELINE.*otherwise" ${tmpfile} | awk '{print $2}' > accounted_for_fieldlist
grep -E "FAIL.*BASELINE.*some baseline files were missing" ${tmpfile} | awk '{print $2}' > accounted_for_missingBaselineFiles
grep -E "FAIL.*BASELINE.*baseline directory.*does not exist" ${tmpfile} | awk '{print $2}' > accounted_for_missingBaselineDir
grep -E "EXPECTED FAILURE" ${tmpfile} | awk '{print $2}' > accounted_for_expectedFail
grep -E "FAIL.*XML*" ${tmpfile} | awk '{print $2}' > accounted_for_xmlFail

# Account for pending tests
[[ -e accounted_for_pend ]] && rm accounted_for_pend
touch accounted_for_pend
for t in $(grep -E "Overall: PEND" ${tmpfile} | awk '{print $1}' | sort); do
    if [[ $(grep $t accounted_for_expectedFail | wc -l) -eq 0 ]]; then
        echo $t >> accounted_for_pend
    fi
done

set -e

for d in $(grep "Overall" ${tmpfile} | awk '{print $1}'); do [[ $(grep $d accounted_for* | wc -l) -eq 0 ]] && ${script} | grep $d; done > not_accounted_for

for f in accounted*; do [[ $f == accounted_for_pend ]] && continue; echo $f; cat $f; echo " "; done

# Print these last
echo accounted_for_pend
cat accounted_for_pend
echo " "
echo not_accounted_for
cat not_accounted_for
echo " "

rm ${tmpfile}
exit 0
