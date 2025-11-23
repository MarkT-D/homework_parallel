#!/bin/bash

STEPS=1000
THREADS=512

sizes=(1000 10000 100000 1000000 10000000)

CSV="results_pthreads_assign2_1.csv"

echo "N,steps,threads,raw_time,normalized_time" > $CSV

echo "Running Pthreads wave equation benchmarks..."
echo "Timesteps: $STEPS"
echo "Threads:   $THREADS"
echo "========================================"

export OMP_NUM_THREADS=$THREADS

for N in "${sizes[@]}"; do
    echo ""
    echo ">>> Running N=$N"

    LOG="run_${N}.log"

    prun -np 1 assign2_1 $N $STEPS $THREADS &> $LOG

    RAW=$(grep -Eo "Took [0-9]+\.[0-9]+ seconds" $LOG | grep -Eo "[0-9]+\.[0-9]+")
    NORM=$(grep -Eo "Normalized: [0-9]+\.[0-9]+e?-?[0-9]* seconds" $LOG | grep -Eo "[0-9]+\.[0-9]+e?-?[0-9]*")

    if [[ -z "$RAW" ]]; then
        RAW="NA"
        echo "  WARNING: Missing raw time"
    fi
    if [[ -z "$NORM" ]]; then
        NORM="NA"
        echo "  WARNING: Missing normalized time"
    fi

    echo "  -> raw: $RAW s"
    echo "  -> normalized: $NORM s"

    echo "$N,$STEPS,$THREADS,$RAW,$NORM" >> $CSV

done

echo ""
echo "All tests completed."
echo "Results saved to $CSV"
