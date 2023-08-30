#!/bin/bash

script="$(get_cs.status)"

tmpfile=.test_summary.$(date "+%Y%m%d%H%M%S%N")
${script} > ${tmpfile}

grep -E "FAIL.*BASELINE.*DIFF" ${tmpfile} | awk '{print $2}' > accounted_for_truediffs
grep -E "FAIL.*BASELINE exception" ${tmpfile} | awk '{print $2}' > accounted_for_baselineException
grep -E "FAIL.*MODEL_BUILD" ${tmpfile} | awk '{print $2}' > accounted_for_modelBuild
grep -E "FAIL.*RUN" ${tmpfile} | grep -v "EXPECTED" | awk '{print $2}' > accounted_for_runFail
grep -E "PASS.*BASELINE" ${tmpfile} | awk '{print $2}' > accounted_for_pass
grep -E "FAIL.*BASELINE.*otherwise" ${tmpfile} | awk '{print $2}' > accounted_for_fieldlist
grep -E "FAIL.*BASELINE.*some baseline files were missing" ${tmpfile} | awk '{print $2}' > accounted_for_missingBaselineFiles
grep -E "FAIL.*BASELINE.*baseline directory.*does not exist" ${tmpfile} | awk '{print $2}' > accounted_for_missingBaselineDir
grep -E "EXPECTED FAILURE" ${tmpfile} | awk '{print $2}' > accounted_for_expectedFail
grep -E "FAIL.*XML*" ${tmpfile} | awk '{print $2}' > accounted_for_xmlFail

for d in $(grep "Overall" ${tmpfile} | awk '{print $1}'); do [[ $(grep $d accounted_for* | wc -l) -eq 0 ]] && ${script} | grep $d; done > not_accounted_for

for f in *accounted*; do echo $f; cat $f; echo " "; done

rm ${tmpfile}
exit 0
