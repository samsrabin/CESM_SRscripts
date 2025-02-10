#!/bin/bash
set -e

timeout=10  # seconds
server_url="svn-ccsm-inputdata.cgd.ucar.edu"

ping -c 1 -w ${timeout} "$server_url" 1>/dev/null 2>&1

exit 0
