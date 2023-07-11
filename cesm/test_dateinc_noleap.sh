#!/bin/bash
set -e

start_datef="1900-02-26"
case_length=2

date_unit="days"

end_datef=$(date --date "${start_datef} +${case_length} ${date_unit}" "+%Y-%m-%d")
echo $end_datef

start_y=$(date --date ${start_datef} "+%Y")
end_y=$(date --date ${end_datef} "+%Y")

if [[ ${start_y



exit 0
