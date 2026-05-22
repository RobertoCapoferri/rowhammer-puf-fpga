#!/bin/bash
mkdir -p ./logs
source .venv/bin/activate
for bg in SOL0 SOL1 CHK1 ROS1 
do
	for nact in 500000 1000000 5000000 10000000
	do
		python3 complete-analysis.py micron $bg $nact | tee ./logs/micron_${bg}_${nact}.log &
	done
done
for bg in SOL0 SOL1 CHK1 ROS1 
do
	for nact in 500000 1000000 5000000 10000000
	do
		python3 complete-analysis.py zentel $bg $nact | tee ./logs/zentel_${bg}_${nact}.log &
	done
done
wait
