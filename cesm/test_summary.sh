#!/bin/bash
set -e

#############################################################################################

script="test_summary.sh"
function usage {
    echo " "
    echo -e "usage: $script [-h|--help] [-i|--only-show-issues] [-n|--quiet-nlfail] [-o|--outdir OUTPUT_DIRECTORY] [-p|--quiet-pending]\n"
}

# Set defaults
quiet_pending=0
quiet_nlfail=0
only_show_issues=0
outdir=

# Args while-loop
while [ "$1" != "" ];
do
    case $1 in

        # Print help
        -h | --help)
            usage
            exit 0
            ;;

        # Only show tests with issues (i.e., don't print pending, pass, or expected fail)
        # Also, don't print lines for empty accounted_for_ files etc.
        -i | --only-show-issues)
            only_show_issues=1
            ;;

        # Don't print NLFAIL tests
        -n | --quiet-nlfail)
            quiet_nlfail=1
            ;;

        # Shortcuts for -i -n
        -in | -ni)
            only_show_issues=1
            quiet_nlfail=1
            ;;

        # Output directory
        -o | --outdir | --out-dir) shift
            outdir=$1
            ;;

        # Don't print pending tests
        -p  | --quiet-pending)
            quiet_pending=1
            ;;

        *)
            echo "$script: illegal option $1"
            usage
            exit 1 # error
            ;;
    esac
    shift
done

# Check run_sys_tests command for limiters
namelists_only=0
if [[ $(head -n 1 SRCROOT_GIT_STATUS) == *"--namelists-only"* ]]; then
    namelists_only=1
fi

#############################################################################################


# File where cs.status output will be saved
tmpfile=.test_summary.$(date "+%Y%m%d%H%M%S%N")

# Set output directory depending on whether user has write access here
izumi_scratch_guess="/scratch/cluster/$USER"
if [[ "${outdir}" == "" ]]; then
    if [[ -w . ]]; then
        outdir=.
    elif [[ "$SCRATCH" != "" ]]; then
        outdir="$SCRATCH/${tmpfile}"
    elif [[ "${HOSTNAME}" == *"izumi"* && -w "${izumi_scratch_guess}" ]]; then
        outdir="${izumi_scratch_guess}/${tmpfile}"
    else
        echo "-o/--outdir not provided but SCRATCH does not exist" >&2
        exit 1
    fi
else
    if [[ ! -d "${outdir}" ]]; then
        mkdir -p "${outdir}"
    fi
    if [[ ! -w "${outdir}" ]]; then
        echo "You don't have write permissions in provided -o/--outdir \"${outdir}\"" >&2
        exit 1
    fi
fi
if [[ "${outdir}" != . ]]; then
    echo "Saving outputs to \"${outdir}/\""
fi
mkdir -p "${outdir}"
tmpfile="${outdir}/${tmpfile}"

excl_dir_pattern="SSPMATRIXCN_.*\.step\w+|ERI.*\.ref\w+|SSP.*\.ref\w+|RXCROPMATURITY.*\.\w+$|PVT.*\.potveg\w*"
$(get_cs.status) \
    | grep -vE "${excl_dir_pattern}" \
    > ${tmpfile}
ntests=$(grep "Overall:" ${tmpfile} | wc -l)

suitedir="$PWD"
cd "${outdir}"

# We don't want the script to exit if grep finds no matches
set +e

rm -f accounted_for_* all_tests not_accounted_for

# Account for completed tests
if [[ ${namelists_only} -eq 1 ]]; then
    filename_pass="accounted_for_nlpass"
else
    grep -E "FAIL.*BASELINE exception" ${tmpfile} | awk '{print $2}' > accounted_for_baselineException
    grep -E "FAIL.*CREATE_NEWCASE" ${tmpfile} | grep -v "EXPECTED" | awk '{print $2}' > accounted_for_createCase
    grep -E "FAIL.*SHAREDLIB_BUILD" ${tmpfile} | grep -v "EXPECTED" | awk '{print $2}' > accounted_for_sharedlibBuild
    grep -E "FAIL.*MODEL_BUILD" ${tmpfile} | grep -v "EXPECTED" | awk '{print $2}' > accounted_for_modelBuild
    grep -E "FAIL.*RUN" ${tmpfile} | grep "UNEXPECTED: expected PEND" | awk '{print $2}' > accounted_for_runFail
    grep -E "FAIL.*RUN" ${tmpfile} | grep -v "EXPECTED" | awk '{print $2}' >> accounted_for_runFail
    grep -E "FAIL.*TPUT" ${tmpfile} | grep -v "EXPECTED" | awk '{print $2}' > accounted_for_throughputFail
    filename_pass="accounted_for_pass"
    grep -E "PASS.*BASELINE" ${tmpfile} | awk '{print $2}' > ${filename_pass} 
    grep -E "FAIL.*COMPARE_base_rest" ${tmpfile} | grep -v "EXPECTED" | awk '{print $2}' > accounted_for_compareBaseRest
    grep -E "FAIL.*COMPARE_base_modpes" ${tmpfile} | grep -v "EXPECTED" | awk '{print $2}' > accounted_for_compareBaseModpes
    grep -E "FAIL.*COMPARE_base_no_interp" ${tmpfile} | grep -v "EXPECTED" | awk '{print $2}' > accounted_for_compareBaseNoInterp
    grep -E "FAIL.*BASELINE.*otherwise" ${tmpfile} | awk '{print $2}' > accounted_for_fieldlist
    grep -E "FAIL.*BASELINE.*some baseline files were missing" ${tmpfile} | awk '{print $2}' > accounted_for_missingBaselineFiles
    grep -E "FAIL.*BASELINE.*baseline directory.*does not exist" ${tmpfile} | awk '{print $2}' > accounted_for_missingBaselineDir
    grep -E "FAIL.*BASELINE.*CPRNC failed to open files" ${tmpfile} | awk '{print $2}' > accounted_for_cprncfailopen
    grep -E "EXPECTED FAILURE" ${tmpfile} | awk '{print $2}' > accounted_for_expectedFail
    grep -E "FAIL.*XML*" ${tmpfile} | awk '{print $2}' > accounted_for_xmlFail
    grep -E "FAIL.*SETUP*" ${tmpfile} | awk '{print $2}' > accounted_for_setupFail

    # Some tests might have BASELINE PASS but TPUT FAIL. Remove them from accounted_for_pass.
    for t in $(cat accounted_for_throughputFail); do
        sed -i "/${t}/d" ${filename_pass}
        #grep -oE "${t} TPUTCOMP.*" ${tmpfile} | sed "s/TPUTCOMP Error://"
    done
fi

# Add a file for tests that failed in NLCOMP, even if they're also in another accounted_for file
grep -E "FAIL.*NLCOMP" ${tmpfile} | awk '{print $2}' > accounted_for_nlfail

if [[ ${namelists_only} -eq 0 ]]; then
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
fi

set -e

# Account for pending tests
touch accounted_for_pend
pattern="Overall: PEND"
for t in $(grep -E "${pattern}" ${tmpfile} | awk '{print $1}' | sort); do
    if [[ ! -e accounted_for_expectedFail || $(grep $t accounted_for_expectedFail | wc -l) -eq 0 ]]; then
        d="$(ls -d "${suitedir}"/$t.[GC0-9]* | grep -vE "${excl_dir_pattern}")"
        nfound=$(echo $d | wc -w)
        if [[ ${nfound} -eq 0 ]]; then
            echo "No directories found for test $t" >&2
            exit 1
        elif [[ ${nfound} -gt 1 ]]; then
            echo "Too many matching directories found for test $t" >&2
            exit 1
        fi
        f=$d/TestStatus.log
        build_nl_failed="build-namelist failed"
        result="$(grep -o "SETUP PASSED\|${build_nl_failed}" $f | tail -n 1)"
        if [[ "${result}" == "${build_nl_failed}" ]]; then
            echo $t >> accounted_for_nlbuildfail
        elif [[ ${namelists_only} -eq 0 && $(grep $t accounted_for_nlfail | wc -l) -eq 0 ]]; then
            echo $t >> accounted_for_pend
        fi
    fi
done

set -e

testlist="$(grep "Overall" ${tmpfile} | awk '{print $1}')"

missing_tests=
for d in ${testlist}; do
    if [[ "$(grep -E "^$d$" accounted_for* | wc -l)" -eq 0 ]]; then
        missing_tests="${missing_tests} $d"
    fi
done

truly_unaccounted=""
for d in ${missing_tests}; do
    n_fail_lines=$(grep " $d " ${tmpfile} | grep FAIL | grep -v "UNEXPECTED: expected FAIL" | wc -l)
    if [[ ${n_fail_lines} -eq 0 ]]; then
        echo $d >> ${filename_pass}
    else
        truly_unaccounted="${truly_unaccounted} $d"
    fi
done
touch not_accounted_for
for d in ${truly_unaccounted}; do
    grep $d ${tmpfile} >> not_accounted_for
done

# Izumi: Check for tests that failed in cleanup
if [[ "$HOSTNAME" == *"izumi"* && $(cat accounted_for_runFail | wc -l) -gt 0 ]]; then
    for t in $(cat accounted_for_runFail); do
        d="$(ls -d ${t}\.* | grep -Ev "ERI.*\.ref[0-9]")"
        n="$(echo $d | wc -w)"
        if [[ $n -ne 1 ]]; then
            # https://github.com/ESCOMP/CTSM/issues/2913#issuecomment-2622943050
            if [[ "${d}" == "SSPMATRIXCN"* && "${d}" == *"step0-AD"* && "${d}" == *"step1-SASU" ]]; then
                continue
            fi
            echo -e "Expected 1 but found $n matches for $t: \n$d" >&2
            exit 1
        fi
        last_cesm_log="$(find ${d} -name "cesm.log\.*" -print0 | xargs -0 ls -tr | grep -vE "\.gz$" | tail -n 1)"
        if [[ $(echo ${last_cesm_log} | wc -w) -eq 0 ]]; then
            continue
        fi
        if [[ "$(grep "med_finalize sysmem" ${last_cesm_log} | wc -l)" -gt 0 ]]; then
            echo $t >> accounted_for_cleanupFail
            sed -i "/^${t}$/d" accounted_for_runFail
        fi
    done
fi

#####################
### Print results ###
#####################

for f in accounted*; do
    [[ $f == accounted_for_pend ]] && continue
    n=$(wc -l $f | cut -d" " -f1)
    [[ ${n} -eq 0 && ${only_show_issues} -eq 1 ]] && continue
    if [[ $f == accounted_for_nlfail && ${quiet_nlfail} -eq 1 ]]; then
        echo "$f ($n)"
        [[ $n -gt 0 ]] && echo "   $n tests had namelist diffs"
        echo " "
        continue
    fi
    if [[ ${only_show_issues} -eq 1 ]]; then
        if [[ $f == ${filename_pass} ]]; then
            echo "$f ($n)"
            [[ $n -gt 0 ]] && echo "   $(wc -l $f | cut -d" " -f1) tests passed"
            echo " "
            continue
        fi
        if [[ $f == accounted_for_expectedFail ]]; then
            echo "$f ($n)"
            [[ $n -gt 0 ]] && echo "   $(wc -l $f | cut -d" " -f1) tests failed as expected"
            echo " "
            continue
        fi
    fi
    echo "$f ($n)"
    cat $f | sort
    echo " "
done

# Print these last

# accounted_for_pend
n=$(wc -l accounted_for_pend | cut -d" " -f1)
if [[ ${n} -gt 0 || ${only_show_issues} -eq 0 ]]; then
    echo "accounted_for_pend ($n)"
    if [[ ${quiet_pending} -eq 0 && ${only_show_issues} -eq 0 ]]; then
        cat accounted_for_pend
    else
        [[ $n -gt 0 ]] && echo "   $n tests pending"
    fi
fi

# not_accounted_for
n=$(wc -l not_accounted_for | cut -d" " -f1)
if [[ ${n} -gt 0 || ${only_show_issues} -eq 0 ]]; then
   echo " "
   echo not_accounted_for
   cat not_accounted_for
   echo " "
fi

cat accounted_for* | grep -v "(EXPECTED FAIL)" | sort | uniq > all_tests
grep "Overall" not_accounted_for | grep -v "(EXPECTED FAIL)" | sort | uniq >> all_tests
#grep "Overall" not_accounted_for | sort | uniq >> all_tests
n=$(cat all_tests | wc -l)
if [[ ${n} -ne ${ntests} ]]; then
    n_missing=$((ntests - n))
    echo "ERROR: EXPECTED $ntests TESTS; MISSING ${n_missing}" >&2
    if [[ ${n_missing} -gt 0 ]]; then
        for t in ${testlist}; do
            n_thistest=$(grep -E "^$t$" *acc* | wc -l)
            [[ ${n_thistest} -eq 0 ]] && echo "   $t"
        done
    fi
    rm ${tmpfile}
    exit 1
fi

rm ${tmpfile}
exit 0
