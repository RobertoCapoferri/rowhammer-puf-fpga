# Rowhammer PUF FPGA Testing Platform

Code supporting the platform described in the paper 
"An FPGA Platform for Evaluating RowHammer-based DRAM PUFs".

## Structure

General overview of the repository structure, each folder contains its own 
README.md with further details.

- `data-analysis` script used for data analysis and plotting and corresponding results
    - `code` Python, bash and awk scripts for the analysis
    - `results` the logs of the analysis runs, the resulting statistics 
        and the all the produced plots.
- `platform` code and scripts needed to setup the platform
    - `cpu` program that runs on the MicroBlaze CPU on the FPGA
    - `fpga-board` vhdl source for the hammer peripheral, IPs for the block design and some specific files for the Nexys Video board
    - `host-pc` data collection script

## Dataset

The dataset collected is available on [Zenodo](https://doi.org/10.5281/zenodo.20393097).
