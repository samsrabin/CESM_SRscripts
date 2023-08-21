#!/bin/bash
set -e

destDir="$PWD"
sourceDir="$1"

function in_to_out {
    echo $1 | sed "s/\[//" | sed "s/\]//" | sed "s/'//g" | sed "s/:/=/g" | sed "s/, /,NTASKS_/g" | sed "s/= /_/"
}

function get_components {
    echo $1 | grep -oE "'[A-Z]+:" | grep -oE "[A-Z]+"
}

destTasks0="$(./xmlquery NTASKS | sed -E "s/^\s+//")"

cd "${sourceDir}"
sourceTasks0="$(./xmlquery NTASKS)"

sourceTasks="${sourceTasks0}"
for component in $(get_components "${sourceTasks0}"); do
    present=$(echo $destTasks0 | grep "'${component}:" | wc -l)
    if [[ ${present} -eq 0 ]]; then
        echo "${component} in source dir but not destination. Will skip."
        sourceTasks=$(echo $sourceTasks | sed -E "s/\['${component}:[0-9]+', //")
        sourceTasks=$(echo $sourceTasks | sed -E "s/, '${component}:[0-9]+'//")
    fi
done

destTasks="${destTasks0}"
for component in $(get_components "${destTasks0}"); do
    present=$(echo $sourceTasks0 | grep "'${component}:" | wc -l)
    if [[ ${present} -eq 0 ]]; then
        echo "WARNING: ${component} not present in source directory. Will not change!"
        destTasks=$(echo $destTasks | sed -E "s/\['${component}:[0-9]+', //")
        destTasks=$(echo $destTasks | sed -E "s/, '${component}:[0-9]+'//")
    fi
done

if [[ "${sourceTasks}" == "${destTasks}" ]]; then
    echo "Both cases have ${sourceTasks}"
    echo "(after finding common compset, if needed)"
    echo "Stopping."
    exit 0
fi

restoreTasks="./xmlchange $(in_to_out "${destTasks}")"
setTasks="./xmlchange $(in_to_out "${sourceTasks}")"

cd "${destDir}"

set +e
$(echo ${setTasks})
set -e

echo " "
echo "Original: $destTasks"
echo "     New: $(./xmlquery NTASKS)"

echo " "
echo "To restore original settings, do"
echo ${restoreTasks}

exit 0
