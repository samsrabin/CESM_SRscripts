#!/bin/bash
set -e

dir_run=$(./xmlquery RUNDIR | sed "s/\tRUNDIR: //")
dir_archive=$(./xmlquery DOUT_S_ROOT | sed "s/\tDOUT_S_ROOT: //")

mkdir ssr_links
cd ssr_links

ln -s "${dir_run}" run
ln -s "${dir_archive}" archive

exit 0
