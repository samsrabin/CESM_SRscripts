#!/bin/bash

# This is an example "chainspec" file to be used as input to submit_chain.sh. Put this in the directory where you have your cases set up. In this example:
# /path/to/cases
# ├── chainspec.sh
# ├── runA
# ├── runB1
# └── runB2
#
# Chainspec files need execute permission. If needed, do:
#     chmod +x chainspec.sh

list_cases=("runA"); list_deps=("")
list_cases+=("runB1"); list_deps+=("runA")
list_cases+=("runB2"); list_deps+=("runA")

# Do not give an exit code, as this is supposed to be called within the chain submission shell.
