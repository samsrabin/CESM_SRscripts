#!/bin/bash
set -e

. cd_custom.sh cases 1>/dev/null
casedir="$(pwd)"

# Transfer logs from run directory
. cd_custom.sh run 1>/dev/null
this_dir="$(pwd)"
if [[ "${this_dir}" != "${casedir}" ]]; then
    . cd_custom.sh cases 1>/dev/null
    if compgen -G "*.log.*" > /dev/null; then
        mkdir -p "run_logs/incomplete"
        rsync -ahm --partial ${this_dir}/*.log.* run_logs/incomplete/
    fi
fi

# Transfer logs from archive directory
. cd_custom.sh st_archive 1>/dev/null 1>/dev/null
this_dir="$(pwd)"
if [[ "${this_dir}" != "${casedir}" ]]; then
    . cd_custom.sh cases 1>/dev/null
    mkdir -p "run_logs/complete"
    rsync -ahm --partial "${this_dir}"/logs/*.log.* "run_logs/complete/"
fi

exit 0
