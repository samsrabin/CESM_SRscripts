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

n_files=0
n_no_bl1=0
n_no_bl2=0
n_diff=0
n_pass=0

for d in *; do
    echo $d

    filelist=$(ls $d/*nc 2>/dev/null)
    if [[ "${filelist}" == "" ]]; then
        echo -e "   ⚠️ No *nc files found in baseline 1 (${b1})\n"
        n_no_bl1=$((n_no_bl1 + 1))
        continue
    fi

    for f in ${filelist}; do
        n_files=$((n_files + 1))
        fb=$(basename $f)

        b2_file="$b1/$f"
        if [[ ! -e "${b2_file}" ]]; then
            echo -e "   ❌ ${fb} not found in baseline 2 (${b2})\n"
            n_no_bl2=$((n_no_bl2 + 1))
            continue
        fi

        bad=$(nccmp -d -x date_written,time_written $f ${b2_file} 2>&1 | wc -l)
        echo -n "   "
        if [[ ${bad} -eq 0 ]]; then
            echo -n ✅
            n_pass=$((n_pass + 1))
        else
            echo -n ❌
            n_diff=$((n_diff + 1))
        fi
        echo " $fb"
    done

    echo " "
done

echo "Summary (${n_files} files):"
[[ ${n_pass} -gt 0 ]] && echo -e "   ${n_pass}\t✅ pass"
[[ ${n_no_bl2} -gt 0 ]] && echo -e "   ${n_no_bl2}\t❌ baseline 2 files missing"
[[ ${n_diff} -gt 0 ]] && echo -e "   ${n_diff}\t❌ files differ"
if [[ ${n_no_bl1} -gt 0 ]]; then
    echo "and:"
    echo -e "   ${n_no_bl1}\t⚠️ baseline 1 dirs with no .nc files"
fi


exit 0
