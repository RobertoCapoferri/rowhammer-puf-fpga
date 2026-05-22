#!/bin/bash
mkdir -p ./stats
for vend in  micron zentel
do
    for nact in 500000 1000000 5000000 10000000
    do
        awk -f stats.awk -v vendor=${vend} ./logs/${vend}_${nact}.log
    done
done
