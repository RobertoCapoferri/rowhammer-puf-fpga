## Data Analysis

Requirements: Python mandatory, awk, bash to use convenience scripts

There are two subfolders here, each described in its own section.


### code

In this folder there is the `complete-analysis.py` script used to 
analyze the data obtained after running the `paper-data-campaign.py` 
script. Library dependencies can be found in `requirements.txt`

In particular this script will:
- compute the `J_intra` metrics for both random and sequential rows
- compute the `J_inter` metric for all the pairs of rows in the 
    uniqueness dataset, as well as the `entropy` of the bit-flip
    distribution

The script outputs logs, that can be post-processed with `stats.awk` 
for easier readability, and plots of the bit-flip distributions.

The scripts `run_analysis.sh` and `run_stats.awk` are used to 
automate the analysis and provide example of the usage.

### paper_results

Contain the output of the `complete-analysis.py` script when run on 
the data that we collected for the paper, in particular:
- `analysis-logs` contain the output logs from the script
- `column-distribution-data-and-plots` data and plots divided by vendor
- `stats` output of `stats.awk` with aggregated stats for all the test
    categories, also divided by vendor