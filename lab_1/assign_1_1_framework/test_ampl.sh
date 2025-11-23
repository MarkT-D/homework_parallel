#!/bin/bash

# run_tests.sh
# Usage: bash run_tests.sh
#
# Runs the wave simulation for problem sizes:
# 10^3, 10^4, 10^5, 10^6, 10^7
# with 1000 time steps and 512 threads.
#
# Uses DAS-5 GPU node (TitanRTX) via prun.

STEPS=1000
THREADS=512

# Array of problem sizes
sizes=(1000 10000 100000 1000000 10000000)

echo "Running Pthreads wave equation benchmarks..."
echo "Timesteps: $STEPS"
echo "Threads:   $THREADS"
echo "========================================"

for N in "${sizes[@]}"; do
    echo ""
    echo ">>> Running N=$N"
    prun -v -np 1 assign1_1 $N $STEPS $THREADS
done

echo ""
echo "All tests completed."
