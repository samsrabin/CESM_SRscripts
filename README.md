# My CESM scripts

These are scripts I've put together for working with CESM on Cheyenne, as well as a few for working on Cheyenne generally. 

I'm happy to listen to feature requests or other issues that you submit, but can't guarantee I'll have the capacity to address them. Feel free to fork this repo, make changes, and submit pull requests!

These are all written in Bash, so if that's your shell of choice you can call them just by invoking their name. Otherwise `bash script_name.sh` should work? I don't know, I'm allergic to other shells (there's a "shell`fsh`" joke in there somewhere). Feel free to email me or submit an issue with better instructions.

Some of these depend on others, so make sure they're on your PATH. E.g., for Bash, add this to your `~/.bash_profile`:

```bash
PATH="$PATH:$HOME/scripts/other"
PATH="$PATH:$HOME/scripts/cesm"
```



## CESM scripts (`cesm/`)

### [`chainspec.sh`](https://github.com/samsrabin/CESM_SRscripts/blob/main/cesm/chainspec.sh)

An example "chainspec" file for use in `submit_chain.sh` (see below).

### [`submit_chain.sh`](https://github.com/samsrabin/CESM_SRscripts/blob/main/cesm/submit_chain.sh)

My idea is to have a script I can call once to submit a job as well as all the jobs dependent on it. This is accomplished by calling `submit_chain.sh` with an argument pointing to a "chainspec" file (see `chainspec.sh` for an example). The chainspec files look basically like this, where runB1 and runB2 depend on state files generated by runA:

```bash
#!/bin/bash
list_cases=("runA"); list_deps=("")
list_cases+=("runB1"); list_deps+=("runA")
list_cases+=("runB2"); list_deps+=("runA")
```

Some features:

- Can have jobs with RESUBMIT>0 (thanks to the `case.submit --resubmit-immediate` flag).
- Performs some sanity checks re: run order, run settings (`CONTINUE_RUN`, `RUN_TYPE`, `RUN_REF*`)
- Offers to remove unexpected restart files found in run directories.

Example usage:

```
cheyenne5:/glade/u/home/samrabin/cases_ctsm$ submit_chain.sh chain_20220726.05.sh
Case "chain_20220726.05.01"
    Starts 1850-01-01
    2 segments, each 5 days
    Produces state for 1850-01-11
Case "chain_20220726.05.02"
    This is a dependent run. Do you want to temporarily overwrite existing RUN_TYPE ("startup") with "branch"? y
    Depends on case "chain_20220726.05.01"
    Do you want to temporarily overwrite existing ref case (ifeuirne) with chain_20220726.05.01? y
    Starts 1850-01-11
    5 days
    Produces state for 1850-01-16

Submitting case "chain_20220726.05.01"
    Restart files already exist in run directory. Continue, Delete restart files, or Abort? d
    rpointer files refer to 1850-01-11 instead of 1850-01-01. Continue, Delete rpointer files, or Abort? d
    jobID_run:     5188445 5188447
    jobID_archive: 5188446 5188448

Submitting case "chain_20220726.05.02"
    Restart files already exist in run directory. Continue, Delete restart files, or Abort? d
    rpointer files refer to 1850-01-16 instead of 1850-01-11. Continue, Delete rpointer files, or Abort? d
    --prereq 5188448
    jobID_run:     5188449
    jobID_archive: 5188450
```

Big thanks to Dan Kennedy and Keith Oleson for inspiration and guidance; any annoyances with this script are on me.

Caveats:

- At the moment, I have it set up so that dependent runs must be branch runs; I'll eventually look into adding the ability for these to be hybrid as well. (Sooner if you submit an issue asking for this!)
- This depends on a CIME version that disables the check for `rpointer` files in `case.submit` when it's called with `--resubmit`. This was introduced 2022-07-27 in  CIME update [97d9f5a](https://github.com/ESMCI/cime/commit/97d9f5a97d160d1d86dbf1972e0a7f85c945bb63).



## Other scripts (`other/`)

### [`cd_custom.sh`](https://github.com/samsrabin/CESM_SRscripts/blob/main/other/cd_custom.sh)

This script allows easy switching between different directories of a given case. For example, if I'm in the case's run directory, I can easily switch to its build, archive, or setup directory. 

Note that I never call this script directly. Instead, I have added four lines to my `~/.bash_profile` (after the addition of the script directories to my PATH):

```bash
alias cdc='. cd_custom.sh cases'
alias cda='. cd_custom.sh st_archive'
alias cdr='. cd_custom.sh run'
alias cdb='. cd_custom.sh bld'
```

So, e.g., from the setup directory `/glade/u/home/samrabin/cases_ctsm/casename/`, I can do `cdr` to quickly switch to the run directory `/glade/scratch/samrabin/cases_ctsm/casename/run/`.

You'll need to customize the `home_casedir` variable to make this work for you.

### [`copy_pes.sh`](https://github.com/samsrabin/CESM_SRscripts/blob/main/other/copy_pes.sh)

Call this like `copy_pes.sh /path/to/sourcecase` from a case setup directory to copy the processor setup (i.e., XML variable `NTASKS`) from `sourcecase` to the case whose directory you're in.

### [`link_case_dirs.sh`](https://github.com/samsrabin/CESM_SRscripts/blob/main/other/link_case_dirs.sh)

From a case setup directory, call this script to create a directory (`dir_links`) with links to the run and archive directories. E.g.:

```
dir_links/
├── archive -> /glade/scratch/samrabin/archive/yield_perharv_smallville
└── run -> /glade/scratch/samrabin/yield_perharv_smallville/run
```

### [`synclogs.sh`](https://github.com/samsrabin/CESM_SRscripts/blob/main/other/synclogs.sh)

Sync all the log files from a case's archive and run directories to a new directory called `run_logs` in its setup directory (subdirectories `run_logs/complete/` and `run_logs/incomplete/`, respectively). Call from setup directory.

I use this to avoid potentially-useful log files (e.g., from troubleshooting) getting deleted due to periodic `/glade/scratch` sweeps.

### [`tfncesm.sh`](https://github.com/samsrabin/CESM_SRscripts/blob/main/other/tfncesm.sh)

Call this from a case's run directory to follow the progress of the latest `atm.log` file. Add any argument to instead follow the latest file with that argument as a prefix; e.g., do `tfncesm.sh cesm.log` to follow the `cesm.log` file instead.

## Notes/caveats

- When I say "case setup directory/folder," I mean the directory that you specify with `--case` when calling `create_newcase` or `create_clone`.
- Many/most of these will probably break if you're in the habit of putting spaces in file or folder names. Sorry about that!
