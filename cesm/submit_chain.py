#!/usr/bin/env python3

"""
Description goes here
"""

import configparser

import sys
sys.path.append("/glade/u/home/samrabin/ctsm_20220801/cime/CIME/Tools/")
from standard_script_setup import *

from CIME.case import Case
from CIME.utils import expect

# SSR
import datetime as dt
from dateutil import parser as du_parser
from dateutil.relativedelta import relativedelta as du_relativedelta
import calendar as cal

# https://stackoverflow.com/a/3041990/2965321
def query_yes_no(question, default="yes"):
    """Ask a yes/no question via raw_input() and return their answer.

    "question" is a string that is presented to the user.
    "default" is the presumed answer if the user just hits <Enter>.
            It must be "yes" (the default), "no" or None (meaning
            an answer is required of the user).

    The "answer" return value is True for "yes" or False for "no".
    """
    valid = {"yes": True, "y": True, "ye": True, "no": False, "n": False}
    if default is None:
        prompt = " [y/n] "
    elif default == "yes":
        prompt = " [Y/n] "
    elif default == "no":
        prompt = " [y/N] "
    else:
        raise ValueError("invalid default answer: '%s'" % default)

    while True:
        sys.stdout.write(question + prompt)
        choice = input().lower()
        if default is not None and choice == "":
            return valid[default]
        elif choice in valid:
            return valid[choice]
        else:
            sys.stdout.write("Please respond with 'yes' or 'no' " "(or 'y' or 'n').\n")


def datef_and_date_from_dt(this_date_dt):
   this_datef = this_date_dt.strftime("%Y-%m-%d")
   this_date = this_datef.replace("-", "")
   return this_date, this_datef


def parse_clmparam_date(some_date):
   # dt.datetime.strptime() can't handle years <1000 without a workaround (https://stackoverflow.com/a/71118317/2965321). dateutil doesn't have the same problem with years <1000, but it does with years >9999. Throw error here rather than later, when trying to do date math.
   some_date_dt = du_parser.parse(some_date)
   some_date, some_datef = datef_and_date_from_dt(some_date_dt)
   return some_date_dt, some_date, some_datef

def get_Nleapdays(dt1, dt2):
    y1 = dt1.year
    y2 = dt2.year
    if y1 == y2:
        Nleapdays = int(cal.isleap(y2) and dt1 <= du_parser(f"{y2}-02-29") <= dt2)
    else:
        Nleapdays = cal.leapdays(y1, y2)
        # cal.leapdays excludes the last year, so:
        if cal.isleap(y2) and dt2 >= du_parser(f"{y2}-02-29"):
            Nleapdays = Nleapdays + 1
    return Nleapdays

def get_state_date(rest_or_stop, start_date_dt, this_length, this_option, noleap=None):
    if "day" in this_option:
        this_length_rd = du_relativedelta(days=this_length)
    elif "month" in this_option:
        this_length_rd = du_relativedelta(months=this_length)
    elif "year" in this_option:
        this_length_rd = du_relativedelta(years=this_length)
    else:
        raise ValueError(f"Not sure how to handle {rest_or_stop}_OPTION {this_option} in calculating state date")
    state_date_dt = start_date_dt + this_length_rd
    state_datef = state_date_dt.strftime("%Y-%m-%d")
    state_date = state_date_dt.strftime("%Y%m%d")

    # Deal with leap days
    Nleapdays = 0
    if "day" in this_option:
        Nleapdays = get_Nleapdays(start_date_dt, state_date_dt)
    if Nleapdays > 0 and noleap != False:
        noleap_in = noleap
        if noleap == None:
            noleap = query_yes_no(f"    Using {rest_or_stop}_OPTION {this_option} can cause issues due to leap days. submit_chain.py has interpreted state_date (from {rest_or_stop} parameters) as {state_datef}, assuming a calendar with leap years. Is that correct?", default=None)
        if noleap:
            while Nleapdays > 0:
                state_date_dt = state_date_dt - du_relativedelta(days=Nleapdays)
                Nleapdays = get_Nleapdays(start_date_dt, state_date_dt)
            state_datef = state_date_dt.strftime("%Y-%m-%d")
            state_date = state_date_dt.strftime("%Y%m%d")
            if noleap_in == None and not query_yes_no(f"    Okay, ignoring leap years, submit_chain.py gets state_date (from {rest_or_stop} parameters) of {state_datef}. Is that correct? If not, will exit.", default=None):
                quit()
    return state_date_dt, state_datef, state_date, noleap



###############################################################################
def parse_command_line(args, description):
    ###############################################################################
    parser = argparse.ArgumentParser(
        description=description, formatter_class=argparse.RawTextHelpFormatter
    )

    CIME.utils.setup_standard_logging_options(parser)

#    parser.add_argument(
#        "caseroot",
#        nargs="?",
#        default=os.getcwd(),
#        help="Case directory to submit.\n" "Default is current directory.",
#    )

    parser.add_argument(
        "chainspec",
        help="Chainspec file.\n" "Required.",
    )

    #    parser.add_argument(
    #        "--top-casedir",
    #        default=os.getcwd(),
    #        help="Directory where cases in chainspec file are set up;\n"
    #        "default is current directory.\n"
    #    )
    #    
#    #    parser.add_argument(
#    #        "--no-submit",
#    #        action="store_true",
#    #        help="Do not submit jobs, but do everything else.",
#    #    )
    
    args = CIME.utils.parse_args_and_handle_standard_logging_options(args, parser)

    return (
        args.chainspec,
    )


###############################################################################
def _main_func(description):
    ###############################################################################
    (
        chainspec,
    ) = parse_command_line(sys.argv, description)

    # save these options to a hidden file for use during resubmit
    config_file = ".submit_options"
    if os.path.exists(config_file):
        os.remove(config_file)

    # Read chain specification file (each line is a dict) to list of dicts
    if not os.path.exists(chainspec):
        raise ValueError(f"chainspec file not found: {chainspec}")
    chain = []
    with open(chainspec, 'r') as f:
        for line in f.readlines():
            chain.append(eval(line))

    # Ensure that each dict in chain has the same keys. Order keys were specified
    # in doesn't matter; keys() always returns alphabetical.
    # We may add more keys later in this script, but we want to make sure the initial
    # specification had all the same keys.
    keys0 = chain[0].keys()
    for x in chain:
        if x.keys() != keys0:
            raise ValueError(f"Some member of chain has keys {[k for k in x.keys()]}, but based on first member we expect keys {[k for k in keys0]}")

    # Check cases and get some info
    for i,this in enumerate(chain):
        print(f"Case {this['case']} ({i})")

        # Make sure case directory exists
        if not os.path.exists(this['case']):
            raise ValueError(f"Case directory {this['case']} not found.")

        with Case(this['case'], read_only=False) as this_case:

            # If dependency...
            if this['dep']:
    
                if i==0:
                    raise ValueError(f"First case in chain isn't allowed a dependency; you specified {x['dep']}")
                print(f"    Depends on {this['dep']}")
    
                # Get parent info, making sure it's before this job in list
                found = False
                for parent in chain[:i]:
                    if parent['case'] == this['dep']:
                        found = True
                        parent_state_date, parent_state_datef = datef_and_date_from_dt(parent['state_date_dt'])
                        # Raise error if parent will produce no state
                        break
                if not found:
                    raise ValueError(f"Case {this['case']} depends on {this['dep']}, which does not precede it in chain.")
                parent_case = Case(parent['case'])
    
                # Make sure CONTINUE_RUN is True
                continue_run = this_case.get_value("CONTINUE_RUN")
                if not continue_run:
                    if query_yes_no(f"This is a dependent run. Do you want to permanently overwrite existing CONTINUE_RUN (False) with True? If no, will exit.", default=None):
                        this_case.set_value("CONTINUE_RUN","TRUE")
                    else:
                        quit()
    
                # Do not allow dependent runs to be startup
                run_type = this_case.get_value("RUN_TYPE").lower()
                if run_type == "startup":
                    if query_yes_no(f"This is a dependent run. Do you want to permanently overwrite existing RUN_TYPE ('startup') with 'hybrid'? If no, will prompt to use 'branch' instead.", default=None):
                        this_case.set_value("RUN_TYPE","hybrid")
                        run_type = this_case.get_value("RUN_TYPE").lower()
                if run_type == "startup":
                    if query_yes_no(f"... Do you want to permanently overwrite existing RUN_TYPE ('startup') with 'branch'? If no, will exit.", default=None):
                        this_case.set_value("RUN_TYPE","branch")
                        run_type = this_case.get_value("RUN_TYPE").lower()
                    else:
                        quit()
    
    
            # Does this run need resubmission?
            Nresubmit = this_case.get_value("RESUBMIT")
            if Nresubmit > 0 and not this_case.get_value("RESUBMIT_SETS_CONTINUE_RUN"):
                if query_yes_no("submit_chain.py can't handle resubmits that don't continue run. Permanently change RESUBMIT_SETS_CONTINUE_RUN to TRUE? If no, will exit.", default=None):
                    this_case.set_value("RESUBMIT_SETS_CONTINUE_RUN", True)
                else:
                    quit()
    
            # Get run length
            stop_option = this_case.get_value("STOP_OPTION").lower()
            segment_length = this_case.get_value("STOP_N")
            case_length = (Nresubmit+1) * segment_length
    
            # Get interval between restarts
            rest_option = this_case.get_value("REST_OPTION").lower()
            rest_interval = this_case.get_value("REST_N")
    
            # Get start and ref dates
            start_date_dt, start_date, start_datef = parse_clmparam_date(this_case.get_value("RUN_STARTDATE"))
            if this['dep']:
                ref_date_dt, ref_date, ref_datef = parse_clmparam_date(this_case.get_value("RUN_REFDATE"))
                if ref_date_dt != parent['state_date_dt']:
                    raise RuntimeError(f"RUN_REFDATE is {ref_datef} but parent's state date is {parent_state_datef}.")
    
            # Print run length/resubmit info
            if Nresubmit > 0:
                print(f"    {Nresubmit+1} segments, each {segment_length} ({stop_option})")
            else:
                print(f"    {segment_length} ({stop_option})")

            # Get state dates and reconcile, if needed
            state_date_fromstop_dt, state_datef_fromstop, state_date_fromstop, noleap = get_state_date("STOP", start_date_dt, case_length, stop_option)
            state_date_fromrest_dt = start_date_dt 
            x = 0
            latest_ok = None
            while state_date_fromrest_dt <= state_date_fromstop_dt:
                latest_ok = state_date_fromrest_dt
                x = x + 1
                state_date_fromrest_dt, state_datef_fromrest, state_date_fromrest, noleap = get_state_date("REST", start_date_dt, x*rest_interval, rest_option, noleap=noleap)
            if not latest_ok:
                raise RuntimeError("Offer to use STOP parameters instead for REST, because current REST parameters will produce no state.")
            state_date_fromrest_dt = latest_ok
            if state_date_fromstop_dt != state_date_fromrest_dt:
                state_date_fromrest, state_datef_fromrest = datef_and_date_from_dt(state_date_fromrest_dt)
                raise RuntimeError(f"State date from STOP parameters is {state_datef_fromstop} but from REST parameters is {state_datef_fromrest}.")
            else:
                state_date_dt = state_date_fromstop_dt
                state_date, state_datef = datef_and_date_from_dt(state_date_dt)

            # Deal with calculated dates inconsistent with parent
            if this['dep'] and start_date_dt != parent["start_date_dt"]:
                raise RuntimeError('start_date_dt != parent["start_date_dt"]')

            # Deal with calculated dates inconsistent with parameters

            # Save important things to chain info
            chain[i]["start_date_dt"] = start_date_dt
            chain[i]["state_date_dt"] = state_date_dt
            chain[i]["segment_length"] = segment_length
            chain[i]["Nresubmit"] = Nresubmit

        # CLOSE with Case(this['case'], read_only=False) as this_case


    # Submit cases
    for i,this in enumerate(chain):
        print(f"Submitting case {this['case']} ({i})")

        with Case(this['case'], read_only=False) as this_case:

            this_case.set_value("PRERUN_SCRIPT", "")

            if this['dep']:

                # Get parent job info
                found = False
                for parent in chain[:i]:
                    if parent['case'] == this['dep']:
                        found = True
                        parent_state_year=parent['state_date_dt'].year
                        parent_state_year_pad = str(parent_state_year).zfill(4)
                        parent_state_datef_pad = parent_state_year_pad + parent['state_date_dt'].strftime("-%m-%d")
                if not found:
                    raise ValueError(f"Case {this['case']} depends on {this['dep']}, which does not precede it in chain.")
                parent_case = Case(parent['case'])

                # Set dependency
                dependency = f"--prereq {parent['jobID']}"

                # Set up prerun script
                prerun_script = f"{os.getcwd()}/{this['case']}/prerun_script.sh"
                this_run_dir = this_case.get_value("RUNDIR")
                parent_rest_dir = parent_case.get_value("RUNDIR").replace(parent['case'], "archive/" + parent['case']).replace("/run", "/rest/") + parent_state_datef_pad + "-00000"
                with open(prerun_script, 'w') as f:
                    f.write(f'''#!/bin/bash
set -e

# Copy restart files
parent_rest_dir="{parent_rest_dir}"
this_run_dir="{this_run_dir}"
cp "$parent_rest_dir"/* "$this_run_dir"/

exit 0
''')
                os.system(f"chmod +x '{prerun_script}'")
                this_case.set_value("PRERUN_SCRIPT", prerun_script)

            # Setup for non-dependent runs
            else:
                dependency = ""

            # Check for existing restart files
            restart_files = \
                    glob.glob(this_rundir + f"/{this['case']}.clm2.r*") + \
                    glob.glob(this_rundir + f"/{this['case']}.datm.r*") + \
                    glob.glob(this_rundir + f"/{this['case']}.cpl.r*") + \
            if restart_files:
                if query_yes_no(f"    Restart files already exist in run directory. Do you want to delete them?", default=None):
                    for f in restart_files:
                        os.remove(f)
                elif not query_yes_no(f"    Okay, do you want to continue? If no, will exit.", default=None):
                    quit()

            # Check that rpointer* files, if any, match the desired start date
            rpointer_files = glob.glob(this_rundir + "/rpointer*")
            rpointed_dates = []
            for f in rpointer_files:
                for line in open(f, "r").readlines():
                    this_date_re = re.search("\.r\.\d+\-\d+\-\d+", line)
                    if this_date_re:
                        this_date = this_date_re.match.replace(".r.", "")
                        rpointed_dates.append(rpointed_dates)
            if rpointed_dates:
                if query_yes_no(f"    rpointer files refer to date(s) other than {}: {rpointed_dates}. Do you want to delete them?", default=None):
                    for f in rpointer_files:
                        os.remove(f)
                elif not query_yes_no(f"    Okay, do you want to continue? If no, will exit.", default=None):
                    quit()

            # Submit case

            # Add jobID to chain

            # Print info


    


        # CLOSE with Case(this['case'], read_only=False) as this_case:








if __name__ == "__main__":
    _main_func(__doc__)
