#!/bin/bash

# run_tests.sh
# Usage: bash run_tests.sh
#
# Runs wave simulation for N = 10^3 ... 10^7
# with 1000 timesteps and 512 threads.
# Results are logged to results_assign1_1.csv

STEPS=1000
THREADS=512

sizes=(1000 10000 100000 1000000 10000000)

CSV="results_assign1_1.csv"
echo "N,steps,threads,raw_time,normalized_time" > $CSV

echo "Running Pthreads wave equation benchmarks..."
echo "Timesteps: $STEPS"
echo "Threads:   $THREADS"
echo "========================================"

for N in "${sizes[@]}"; do
    echo ""
    echo ">>> Running N=$N"

    LOG="run_${N}.log"

    # Capture full prun output into a log file
    prun -v -np 1 assign1_1 $N $STEPS $THREADS &> $LOG

    # Extract timing data from program output
    RAW=$(grep -Eo "Took [0-9]+\.[0-9]+ seconds" "$LOG" | grep -Eo "[0-9]+\.[0-9]+")
    NORM=$(grep -Eo "Normalized: [0-9]+\.[0-9]+e?-?[0-9]* seconds" "$LOG" | grep -Eo "[0-9]+\.[0-9]+e?-?[0-9]*")

    if [[ -z "$RAW" ]]; then
        RAW="NA"
        echo "  WARNING: missing raw time for N=$N"
    fi

    if [[ -z "$NORM" ]]; then
        NORM="NA"
        echo "  WARNING: missing normalized time for N=$N"
    fi

    echo "  -> raw time: $RAW s"
    echo "  -> normalized: $NORM s"

    # Append to CSV
    echo "$N,$STEPS,$THREADS,$RAW,$NORM" >> $CSV
done

echo ""
echo "All tests completed."
echo "Results saved to $CSV"
