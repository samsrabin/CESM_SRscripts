#!/bin/bash
set -e

# Read chain specification file
chainspec="$1"
if [[ "${chainspec}" == "" ]]; then
    echo "You must specify chainspec file"
    exit 1
elif [[ ! -e "${chainspec}" ]]; then
    echo "chainspec file not found: ${chainspec}"
    exit 1
fi
cd "$(realpath "$(dirname "${chainspec}")")"
. "$(basename "${chainspec}")"

# Check chain specification file
if [[ ${#list_cases[@]} -ne ${#list_deps[@]} ]]; then
    echo "Lists of cases and dependencies have different number of members (${#list_cases[@]}, ${#list_deps[@]})"
    exit 1
fi

function date_to_datef {
    start_date="$1"
    start_md=${start_date: -4}
    start_y=${start_date/${start_md}/}
    start_d=${start_md: -2}
    start_m=${start_md:0:2}
    echo "${start_y}-${start_m}-${start_d}"
}

function get_last_jobID {
   # If resubmitting, this will get the ID of the LAST segment. 
   whichjob="$1"
   jobID="$(grep -oE "Submitted job ${whichjob} with id [0-9]+" submit_log | sed "s/Submitted job ${whichjob} with id//")"
   if [[ "${jobID}" == "" ]]; then
       echo "Job ID for ${whichjob} not found" >&2
       exit 1
   fi
   echo ${jobID}
}

function get_all_jobIDs {
   # If resubmitting, this will get the IDs of ALL segments.
   whichjob="$1"
   jobIDs="$(grep -A 1 -E "Submitting job script.*${whichjob}" submit_log | grep -oE "job id is [0-9]+" | sed "s/job id is //")"
   if [[ "${jobIDs}" == "" ]]; then
       echo "Job ID(s) for ${whichjob} not found" >&2
       exit 1
   fi
   echo "${jobIDs}"
}

function get_archive_dir {
   thiscase="$1"
   echo /glade/scratch/$USER/archive/${thiscase}
}

function get_run_dir {
   thiscase="$1"
   echo /glade/scratch/$USER/${thiscase}/run
}

# Check cases and print some info
segment_lengths=()
case_lengths=()
start_dates=()
start_dates_orig=()
start_datefs=()
ref_dates=()
ref_dates_orig=()
ref_datefs=()
ref_cases=()
ref_cases_orig=()
state_dates=()
state_datefs=()
stop_date_units=()
run_types=()
N_resubmits=()
continue_runs=()
continue_runs_orig=()
for c in "${!list_cases[@]}"; do
    thiscase="${list_cases[c]}"
    thisdep="${list_deps[c]}"
    
    echo "Case \"${thiscase}\""

    # Make sure case dir exists
    if [[ ! -d "${thiscase}" ]]; then
        echo "Error: Case directory $PWD/${thiscase} not found."
        exit 1
    fi

    cd "${thiscase}"

    # If dependency...
    if [[ "${thisdep}" != "" ]]; then
        
        # Make sure parent job is before in list
        if [[ ${c} -eq 0 ]]; then
            echo "Error: First case in chain is not allowed a dependency; you specified \"${thisdep}\""
            exit 1
        else
            found=0
            for p in $(seq 0 $((c-1))); do
                if [[ "${list_cases[p]}" == "${thisdep}" ]]; then
                    found=1
                    parent_start_date=${start_dates[p]}
                    parent_state_date=${state_dates[p]}
                    parent_state_datef=${state_datefs[p]}
                    parent_segment_length=${segment_lengths[p]}
                    parent_Nresubmit=${Nresubmits[p]}
                    break
                fi
            done
            if [[ ${found} -eq 0 ]]; then
                echo "Error: Case \"${thiscase}\" depends on \"${thisdep}\", which does not precede \"${thiscase}\" in list."
                exit 1
            fi
        fi

        # Make sure CONTINUE_RUN is TRUE
        continue_run=$(./xmlquery CONTINUE_RUN | grep -oE "[A-Za-z]+$")
        continue_runs_orig+=(${continue_run})
        if [[ ${continue_run} != "TRUE" ]]; then
            while true; do
                read -p "    This is a dependent run. Do you want to temporarily overwrite existing CONTINUE_RUN (${continue_run}) with TRUE? " yn
                case $yn in
                    [Yy]* ) break;;
                    [Nn]* ) echo "Exiting."; exit 1;;
                    * ) echo "Please answer yes or no.";;
                esac
            done
            continue_run="TRUE"
        fi
        continue_runs+=(${continue_run})

        # Make sure it's a branch run.
        # Dependent runs being hybrid is not yet supported here.
        run_type=$(./xmlquery RUN_TYPE | grep -oE "[A-Za-z]+$")
        run_types_orig+=(${run_type})
        if [[ $(echo "${run_type}" | tr '[:upper:]' '[:lower:]') != "branch" ]]; then
            while true; do
                read -p "    This is a dependent run. Do you want to temporarily overwrite existing RUN_TYPE (\"${run_type}\") with \"branch\"? " yn
                case $yn in
                    [Yy]* ) break;;
                    [Nn]* ) echo "Exiting."; exit 1;;
                    * ) echo "Please answer yes or no.";;
                esac
            done
            run_type="branch"
        fi
        run_types+=(${run_type})

    else

        continue_runs_orig+=("FALSE")
        continue_runs+=("FALSE")
        run_type=$(./xmlquery RUN_TYPE | grep -oE "[A-Za-z]+$")
        run_types_orig+=(${run_type})
        run_types+=(${run_type})

    fi
    if [[ "${thisdep}" != "" ]]; then
        echo "    Depends on case \"${thisdep}\""
    fi

    # Does this run need resubmission?
    Nresubmit="$(./xmlquery RESUBMIT | grep -oE "[0-9]+$")"
    if [[ ${Nresubmit} -gt 0 && "$(./xmlquery RESUBMIT_SETS_CONTINUE_RUN | grep -oE "[A-Za-z]+$")" != "TRUE" ]]; then
        echo "submit_chain.sh can't handle resubmits that don't continue run."
        exit 1
    fi
    Nresubmits+=(${Nresubmit})

    # Get run length
    stop_option=$(./xmlquery STOP_OPTION | grep -oE "[a-z]+$")
    segment_length="$(./xmlquery STOP_N | grep -oE "[0-9]+$")"
    segment_lengths+=(${segment_length})
    case_length=$(((Nresubmit+1)*segment_length))
    case_lengths+=(${case_length})
    if [[ "${stop_option}" == "nday"* ]]; then
        stop_date_unit="days"
        echo "Using STOP_OPTION ${stop_option} can cause issues with leap days. Currently not supported."
        exit 1
    elif [[ "${stop_option}" == "nmonth"* ]]; then
        stop_date_unit="months"
    elif [[ "${stop_option}" == "nyear"* ]]; then
        stop_date_unit="years"
    else
        echo "Not sure how to handle STOP_OPTION ${stop_option} in calculating state date"
        exit 1
    fi
    stop_date_units+=(${stop_date_unit})

    # Get interval between restarts
    rest_option=$(./xmlquery REST_OPTION | grep -oE "[a-z]+$")
    rest_interval="$(./xmlquery REST_N | grep -oE "[0-9]+$")"
    if [[ "${rest_option}" == "nday"* ]]; then
        rest_date_unit="days"
        echo "Using REST_OPTION ${rest_option} can cause issues with leap days. Currently not supported."
        exit 1
    elif [[ "${rest_option}" == "nmonth"* ]]; then
        rest_date_unit="months"
    elif [[ "${rest_option}" == "nyear"* ]]; then
        rest_date_unit="years"
    else
        echo "Not sure how to handle REST_OPTION ${rest_option} in calculating state date"
        exit 1
    fi
    rest_date_units+=(${rest_date_unit})

    # Get start and ref dates
    start_date=$(./xmlquery RUN_STARTDATE | grep -oE "[0-9\-]+" | sed "s/-//g")
    start_dates_orig+=(${start_date})
    start_datef=$(date_to_datef "${start_date}")
    if [[ "${thisdep}" != "" ]]; then
        if [[ ${parent_state_date} -ne ${start_date} ]]; then
            while true; do
                read -p "    Do you want to temporarily overwrite existing start date (${start_datef}) with ${parent_state_datef}? " yn
                case $yn in
                    [Yy]* ) break;;
                    [Nn]* ) echo "Exiting."; exit 1;;
                    * ) echo "Please answer yes or no.";;
                esac
            done
            start_date=${parent_state_date}
            start_datef=${parent_state_datef}
        fi
        ref_date=$(./xmlquery RUN_REFDATE | grep -oE "[0-9\-]+" | sed "s/-//g")
        ref_dates_orig+=(${ref_date})
        ref_datef=$(date_to_datef "${ref_date}")
        if [[ ${parent_state_date} -ne ${ref_date} ]]; then
            while true; do
                read -p "    Do you want to temporarily overwrite existing ref date (${ref_datef}) with ${parent_state_datef}? " yn
                case $yn in
                    [Yy]* ) break;;
                    [Nn]* ) echo "Exiting."; exit 1;;
                    * ) echo "Please answer yes or no.";;
                esac
            done
            ref_date=${parent_state_date}
            ref_datef=${parent_state_datef}
        fi
        ref_cases+=(${ref_case})
        ref_case=$(./xmlquery RUN_REFCASE | awk 'NF>1{print $NF}')
        ref_cases_orig+=(${ref_case})
        if [[ ${thisdep} != ${ref_case} ]]; then
            while true; do
                read -p "    Do you want to temporarily overwrite existing ref case (${ref_case}) with ${thisdep}? " yn
                case $yn in
                    [Yy]* ) break;;
                    [Nn]* ) echo "Exiting."; exit 1;;
                    * ) echo "Please answer yes or no.";;
                esac
            done
            ref_case=${parent_state_case}
        fi
        ref_cases+=(${ref_case})
    fi
    start_dates+=(${start_date})
    start_datefs+=(${start_datef})
    echo "    Starts ${start_datef}"

    # Print run length/resubmit info
    if [[ ${Nresubmit} -gt 0 ]]; then
        echo "    $((Nresubmit+1)) segments, each ${segment_lengths[c]} ${stop_date_unit}"
    else
        echo "    ${segment_lengths[c]} ${stop_date_unit}"
    fi

    # Get state date
    state_datef_fromstop="$(date --date "${start_datef} +${case_length} ${stop_date_unit}" "+%Y-%m-%d")"
    state_date_fromstop="$(echo ${state_datef_fromstop} | sed "s/-//g")"
    state_datef_fromrest="$(date --date "$(date_to_datef ${start_date}) +${rest_interval} ${rest_date_unit}" "+%Y-%m-%d")"
    state_date_fromrest="$(echo ${state_datef_fromrest} | sed "s/-//g")"
    while [[ ${state_date_fromrest} -le ${state_date_fromstop} ]]; do
        state_date_fromrest_latestok=${state_date_fromrest}
        state_datef_fromrest="$(date --date "$(date_to_datef ${state_date_fromrest}) +${rest_interval} ${rest_date_unit}" "+%Y-%m-%d")"
        state_date_fromrest="$(echo ${state_datef_fromrest} | sed "s/-//g")"
    done
    if [[ ${state_date_fromrest_latestok} == "" ]]; then
        echo "Cowardly refusing to let you do a run with no state saved. Do ./xmlchange REST_N=${segment_length},REST_OPTION=${stop_option} to at least save at the end of the run."
        exit 1
    fi
    state_date_fromrest=${state_date_fromrest_latestok}
    state_datef_fromrest="$(date_to_datef ${state_date_fromrest})"
    if [[ ${state_date_fromrest} -ne ${state_date_fromstop} ]]; then
        while true; do
            read -p "    STOP_OPTION*STOP_N would produce state for ${state_datef_fromstop}, but last restart date from REST_OPTION*REST_N will be ${state_datef_fromrest}. Which do you want dependent runs to resume from, Stop or Rest? Or you can Abort. " sra
            case $sra in
                [Ss]* ) state_date=${state_date_fromstop}; break;;
                [Rr]* ) state_date=${state_date_fromrest}; break;;
                [Aa]* ) echo "Exiting."; exit 1;;
                * ) echo "    Please answer Stop, Rest, or Abort";;
            esac
        done
        while [[ ${state_date} -eq ${state_date_fromstop} ]]; do
            read -p "    WARNING: This will permanently overwrite the current settings REST_N=${rest_interval},REST_OPTION=${rest_option} with the values from STOP_N=${segment_length},STOP_OPTION=${stop_option}. Continue? " yn
            case $yn in
                [Yy]* ) ./xmlchange REST_N=${segment_length},REST_OPTION=${stop_option}; break;;
                [Nn]* ) echo "Exiting."; exit 1;;
                * ) echo "    Please answer Yes or No.";;
            esac
        done
        state_datef=$(date_to_datef ${state_date})
    else
        state_date=${state_date_fromstop}
        state_datef=${state_datef_fromstop}
    fi
    state_dates+=(${state_date})
    state_datefs+=(${state_datef})
    echo "    Produces state for ${state_datef}"

    cd ..

done

echo " "


# Submit cases
last_jobIDs=()
for c in "${!list_cases[@]}"; do
    thiscase="${list_cases[c]}"
    thisdep="${list_deps[c]}"
    start_date=${start_dates[c]}
    start_date_orig=${start_dates_orig[c]}
    start_datef=${start_datefs[c]}
    ref_date=${ref_dates[c]}
    ref_date_orig=${ref_dates_orig[c]}
    ref_datef=${ref_datefs[c]}
    ref_case=${ref_cases[c]}
    ref_date_orig=${ref_dates_orig[c]}
    segment_length=${segment_lengths[c]}
    continue_run=${continue_runs[c]}
    continue_run_orig=${continue_runs_orig[c]}
    run_type=${run_types[c]}
    run_type_orig=${run_types_orig[c]}

    echo "Submitting case \"${thiscase}\""
    cd "${thiscase}"

    ./xmlchange PRERUN_SCRIPT=""

    if [[ "${continue_run}" != "${continue_run_orig}" ]]; then
        ./xmlchange CONTINUE_RUN="${continue_run}"
    fi
    if [[ "${run_type}" != "${run_type_orig}" ]]; then
        ./xmlchange RUN_TYPE="${run_type}"
    fi

    # Setup for dependent runs
    if [[ ${thisdep} != "" ]]; then

        if [[ "${start_date}" != "${start_date_orig}" ]]; then
            ./xmlchange RUN_STARTDATE="${start_date}"
        fi
        if [[ "${ref_date}" != "${ref_date_orig}" ]]; then
            ./xmlchange RUN_REFDATE="${ref_date}"
        fi
        if [[ "${ref_case}" != "${ref_case_orig}" ]]; then
            ./xmlchange RUN_REFCASE="${ref_case}"
        fi

        # Get parent job ID
        for p in $(seq 0 $((c-1))); do
            if [[ "${list_cases[p]}" == "${thisdep}" ]]; then
                parent_jobID=${last_jobIDs[p]}
                parent_state_datef=${state_datefs[p]}
                parent_state_year=$(echo ${parent_state_datef} | cut -d"-" -f 1)
                parent_state_year_pad=$(printf "%04d" ${parent_state_year})
                parent_state_datef_pad=${parent_state_datef/${parent_state_year}/${parent_state_year_pad}}
                break
            fi
        done
        dependency="--prereq ${parent_jobID}"

        # Set up PRERUN_SCRIPT
        cat <<EOL > prerun_script.sh
#!/bin/bash
set -e

# Copy restart files
parent_rest_dir="$(get_archive_dir ${thisdep})/rest/${parent_state_datef_pad}-00000"
this_run_dir="$(get_run_dir ${thiscase})"
cp "\${parent_rest_dir}"/* \${this_run_dir}/

exit 0
EOL
        chmod +x prerun_script.sh
        ./xmlchange PRERUN_SCRIPT="$PWD/prerun_script.sh"


    # Setup for non-dependent runs
    else
        dependency=""
    fi

    # Check for existing restart files
    this_rundir="$(get_run_dir "${thiscase}")"
    restart_files="$(find "${this_rundir}" -maxdepth 1 -name "${thiscase}.clm2.r*" -or -name "${thiscase}.datm.r*"  -or -name "${thiscase}.cpl.r*")"
    if [[ "${restart_files}" != "" ]]; then
        while true; do
            read -p "    Restart files already exist in run directory. Continue, Delete restart files, or Abort? " yn
            case $yn in
                [Cc]* ) break;;
                [Dd]* ) rm ${restart_files}; break;;
                [Aa]* ) echo "Aborting."; exit 1;;
                * ) echo "Please answer Continue, Delete, or Abort.";;
            esac
        done
    fi

    # Check that rpointer* files, if any, match the desired start date
    if compgen -G "${this_rundir}/rpointer*" > /dev/null ; then
        rpointed_dates="$(grep -hoE "\.r\.[0-9]+\-[0-9]+\-[0-9]+" "${this_rundir}"/rpointer* | sed "s/.r.//" | sort | uniq)"
        if [[ $(echo "${rpointed_dates}" | wc -l) -gt 1 ]]; then
            while true; do
                read -p "    rpointer files refer to multiple dates. Continue, Delete rpointer files, or Abort? " yn
                case $yn in
                    [Cc]* ) break;;
                    [Dd]* ) rm "${this_rundir}"/rpointer*; break;;
                    [Aa]* ) echo "Aborting."; exit 1;;
                    * ) echo "Please answer Continue, Delete, or Abort.";;
                esac
            done
        elif [[ "${rpointed_dates}" != "${start_datef}" ]]; then
            while true; do
                read -p "    rpointer files refer to ${rpointed_dates} instead of ${start_datef}. Continue, Delete rpointer files, or Abort? " yn
                case $yn in
                    [Cc]* ) break;;
                    [Dd]* ) rm "${this_rundir}"/rpointer*; break;;
                    [Aa]* ) echo "Aborting."; exit 1;;
                    * ) echo "Please answer Continue, Delete, or Abort.";;
                esac
            done
        fi
    fi

    # Submit case.
    # --resubmit-immediate makes it so that all jobs in the resubmit chain are submitted
    # now, so we can get their job IDs.
    set +e
    ./case.submit --resubmit-immediate ${dependency} 1>submit_log 2>&1
    result=$?
    set -e
    if [[ ${result} -ne 0 ]]; then
        cat submit_log
        exit ${result}
    fi

    last_jobID_archive=$(get_last_jobID "case.st_archive")
    last_jobIDs+=(${last_jobID_archive})

    if [[ "${dependency}" != "" ]]; then
        echo "    ${dependency}"
    fi
    echo "    jobID_run:     "$(get_all_jobIDs "case.run")
    echo "    jobID_archive: "$(get_all_jobIDs "case.st_archive")
    echo " "

    rm submit_log


    # Reset to original values
    if [[ "${start_date}" != "${start_date_orig}" ]]; then
        ./xmlchange RUN_STARTDATE="${start_date_orig}"
    fi
    if [[ "${ref_date}" != "${ref_date_orig}" ]]; then
        ./xmlchange RUN_REFDATE="${ref_date_orig}"
    fi
    if [[ "${ref_case}" != "${ref_case_orig}" ]]; then
        ./xmlchange RUN_REFCASE="${ref_case_orig}"
    fi
    if [[ "${continue_run}" != "${continue_run_orig}" ]]; then
        ./xmlchange CONTINUE_RUN="${continue_run_orig}"
    fi
    if [[ "${run_type}" != "${run_type_orig}" ]]; then
        ./xmlchange RUN_TYPE="${run_type_orig}"
    fi

    cd ..

done

exit 0
