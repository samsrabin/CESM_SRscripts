#!/bin/bash
set -e

if [[ ${NCAR_HOST} != "derecho" ]]; then
    echo "move_128dev_to_main.sh can only be run on Derecho." >&2
    exit 1
fi

# Get 128-cpu jobs that are in the cpudev queue
joblist=$(qstat -u $USER | grep " cpudev " | grep " 128 " | grep " Q " | cut -d. -f1)

# Move them to the main queue
for j in ${joblist}; do
    echo $j
    qmove main $j
done

exit 0
