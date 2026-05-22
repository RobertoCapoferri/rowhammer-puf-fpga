# log files are composed of 4 sections
# each delimited by #### <vendor>_<bg>_nact
# so we can compute stats for each one
# vendor is passed via command line
BEGIN {
    mode = 0; #1 = control, 2 = rand_row_rep, 3 = uniq, 4 = seq_row_rep
    tag = ""; # store the tag delimited by #####
    # this filter applies to our analysis, edit as needed (note that this is passed as is
    # to the command that creates the folder)
    if (!(vendor == "micron" || vendor == "zentel")) {
        print "need to pass vendor (-v vendor=[micron|zentel])";
        print vendor;
        exit;
    }
    # set out dir and create it if necessary
    out_dir = "./stats/" vendor "/";
    system("mkdir -p " out_dir);  # careful what you accept as out_dir...
    # log files
    control_logs = out_dir "control_logs.txt"; # stats on control tests
    seq_rep_logs = out_dir "seq_rep_logs.txt"; # stats on seq_rep tests
    rand_rep_logs = out_dir "rand_rep_logs.txt"; # stats on rand_rep tests
    uniq_logs = out_dir "uniq_logs.txt"; # stats on uniq tests
    # used to compute average stats
    sum_vals = 0;
    n_vals = 0;
    min_val = 999;
}
# function for avg and min computation
function avg_and_min_track(id)
{
    if ($1 == id) {
        # keep count of jintra for average
        sum_vals += $3;
        n_vals += 1;
        # track min
        if ($5 < min_val) { min_val = $5; }
    }
}

# output stats, switch mode and reset variables
$1 == "#####" {
    tag = $0;
    mode++;
    # output stats to corresponding files
    switch (mode) {
        case 1:
            print tag > control_logs;
            break;
        case 3: # done when switching to from rand_row_rep to uniq
            avg = sum_vals/n_vals;
            printf("[%s] avg jintra for randomly selected rows = %.3f (min: %.3f)\n", tag, avg, min_val) > rand_rep_logs;
            # add tag to uniq logs
            print tag > uniq_logs;
            break;
        default:
            break; # no action
    }
    # reset all
    sum_vals = 0; n_vals = 0; min_val = 999;
}
# compute statistic according to the sections we are in
$1 != "#####" {
    switch (mode) {
        case 1:
            # just echo the rows to the control file
            print $0 > control_logs
            break;
        case 2:
            # ignore flip stats for this, we use the uniqueness
            avg_and_min_track("[rand_rows_rep_jintra]")
            break;
        case 3:
            # output rows as is, skipping useless prints
            if ($1 != "row") {
                print $0 > uniq_logs;
            }
            break;
        case 4:
            # ignore flip stats for this, we use the uniqueness
            avg_and_min_track("[seq_rows_rep_jintra]")
            break;
        default:
            break;
    }
}
END {
    if (vendor == "") {
        exit; # needed her because exiting in the begin runs end anyway
    }
    # print for the seq_rep_rows
    avg = sum_vals/n_vals;
    printf("[%s] avg jintra for sequentially selected rows = %.3f (min: %.3f)\n", tag, avg, min_val) > seq_rep_logs;
}
