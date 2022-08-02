#!/bin/bash

# Customize this: the directory in your $HOME folder where you set up your cases.
# Mine is $HOME/cases_ctsm, so:
home_casedir="cases"

dest_codes=("cases" "st_archive" "run")

dest="${1}"
if [[ "${dest}" == "" ]]; then
    echo "You must provide destination directory code. Options:"
    for d in "${dest_codes[@]}"; do
        echo "    $d"
    done
    return
fi

# Parse case
n_logname=0

# In $HOME/cases
# Only works on user's home directory, not anyone else's
if [[ "${PWD}" == "${HOME}/${home_casedir}"* ]]; then
    #echo "In \$HOME/${home_casedir}"
    n=7
    n_logname=5

# In short-term archive
elif [[ "${PWD}" =~ /glade/scratch/[a-z]+/archive/.* ]]; then
    #echo "In short-term archive"
    n=6
    n_logname=4

# In scratch
elif [[ "${PWD}" =~ /glade/scratch/[a-z]+ ]]; then
    #echo "In scratch"
    n=5
    n_logname=4

else
    echo "Unable to parse \$PWD"
    return
fi
case=$(echo $PWD | cut -d "/" -f $n)
if [[ $n_logname -gt 0 ]]; then
    logname=$(echo $PWD | cut -d "/" -f $n_logname)
    #echo $logname
fi

if [[ "${case}" == "" ]]; then
    echo "Unable to parse case"
    return
fi

# Change to target directory
already_there=0
keep_going=1
if [[ "${dest}" == "cases" ]]; then
    dest_dir="${HOME}/${home_casedir}/${case}"
    # Not robust to paths with spaces
    if [[ ! -d "${dest_dir}" ]]; then
#        echo "Case not found in \$HOME/${home_casedir}. Looking in all \$HOME/*cases*"
#         dest_dir="$(find $HOME  -type d -wholename "$HOME/*cases*/${case}")"
         dest_dir="$(find $HOME -maxdepth 2 -type d -wholename "$HOME/*cases*/${case}")"
#        dest_dir="$(find $HOME -wholename "$HOME/*cases*/${case}" -and -not \( -wholename "*Buildconf*" -or -wholename "*CaseDocs*" -or -wholename "*cmake_macros*" -or -wholename "*LockedFiles*" -or -wholename "*logs*" -or -wholename "*SourceMods*" -or -wholename "*timing*" -or -wholename "*Tools*" \))"
        # Not robust to paths with spaces
        Ndirs="$(echo $dest_dir | wc -w)"
        if [[ $Ndirs -eq 0 ]]; then
            echo "No directory found with 'find $HOME -maxdepth 2 -type d -wholename \"$HOME/*cases*/${case}\"'"
            keep_going=0
        elif [[ $Ndirs -gt 1 ]]; then
            echo "Multiple possible case directories found:"
            for d in ${dest_dir}; do
                echo "   $d"
            done
            keep_going=0
        fi
    fi
elif [[ "${dest}" == "st_archive" ]]; then
    if [[ "${case}" == "archive" ]]; then
        already_there=1
    fi
    dest_dir="/glade/scratch/$logname/archive/${case}"
elif [[ "${dest}" == "run" ]]; then
    dest_dir="/glade/scratch/$logname/${case}/run"
elif [[ "${dest}" == "bld" ]]; then
    dest_dir="/glade/scratch/$logname/${case}/bld"
else
    echo "What should target directory look like for dest ${dest} ?"
    return
fi

if [[ $keep_going -eq 1 ]]; then
   if [[ "$(realpath $PWD)" == "$(realpath "${dest_dir}")" ]]; then
       already_there=1
   fi
   
   if [[ $already_there -eq 0 ]]; then
       if [[ ! -d "${dest_dir}" ]]; then
           echo "Directory not found: ${dest_dir}"
       else
#           echo $dest_dir
           cd "${dest_dir}"
       fi
   fi
fi


