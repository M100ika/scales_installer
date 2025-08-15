#!/bin/bash
for i in $(seq 1 $(nproc)); do
    while :; do :; done &
done
wait


# pkill -f stress.sh
# vcgencmd measure_temp
