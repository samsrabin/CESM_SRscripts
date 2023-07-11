#!/bin/bash
set -e

testmod_dir="$1"
if [[ ! -d "${testmod_dir}" ]]; then
    echo "testmod_dir not found: ${testmod_dir}" >&2
    exit 1
fi

cd "${testmod_dir}"

if [[ -f include_user_mods ]]; then
    if [[ $(wc -l include_user_mods | cut -d" " -f1) -gt 1 ]]; then
        echo "Expected one line in include_user_mods; got $(wc -l include_user_mods)" >&2
        exit 1
    fi
    parent_mod_dir=$(cat include_user_mods)
    trace_tests.sh "${parent_mod_dir}"
fi

basename $(realpath .)


exit 0
