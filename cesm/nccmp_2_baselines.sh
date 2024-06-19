#!/bin/bash

b1="$1"; shift
b2="$1"; shift

if [[ "$b1" == "" || "$b2" == "" ]]; then
    echo "You must provide two baseline directories to compare" >&2
    exit 1
elif [[ ! -d "$b1" ]]; then
    echo "Baseline 1 doesn't exist: $b1" >&2
    exit 1
elif [[ ! -d "$b2" ]]; then
    echo "Baseline 2 doesn't exist: $b2" >&2
    exit 1
fi

module load nccmp

cd $b1

for d in *; do
    echo $d

    filelist=$(ls $d/*nc 2>/dev/null)
    if [[ "${filelist}" == "" ]]; then
        echo -e "   ⚠️ No *nc files found in baseline 1 (${b1})\n"
        continue
    fi

    for f in ${filelist}; do
        fb=$(basename $f)

        b2_file="$b1/$f"
        if [[ ! -e "${b2_file}" ]]; then
            echo -e "   ❌ ${fb} not found in baseline 2 (${b2})\n"
            continue
        fi

        bad=$(nccmp -d -x date_written,time_written $f ${b2_file} 2>&1 | wc -l)
        echo -n "   "
        if [[ ${bad} -eq 0 ]]; then
            echo -n ✅
        else
            echo -n ❌
        fi
        echo " $fb"
    done

    echo " "
done
exit 0
