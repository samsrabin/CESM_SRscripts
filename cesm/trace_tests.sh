#!/bin/bash
set -e

testmod_dir="$1"
if [[ ! -d "${testmod_dir}" ]]; then
    echo "testmod_dir not found: ${testmod_dir}" >&2
    exit 1
fi

cd "${testmod_dir}"

if [[ -f include_user_mods ]]; then
    for parent_mod_dir in $(cat include_user_mods); do
        trace_tests.sh "${parent_mod_dir}"
    done
fi

echo " "
echo "=== $(basename $(realpath .)) ==="
for f in *; do
    echo $f
    cat $f
    echo " "
done


exit 0
