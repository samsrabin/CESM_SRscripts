#!/bin/bash

pattern="atm.log*"
if [[ "${1}" != "" ]]; then
    pattern="${pattern/atm.log/$1}"
fi
file="$(ls -tr ${pattern} 2>/dev/null | tail -n 1)"

if [[ "${file}" == "" ]]; then
    echo "No file found matching ${pattern}"
else
    echo ${file}
    tail -f -n 100 "${file}"
fi

