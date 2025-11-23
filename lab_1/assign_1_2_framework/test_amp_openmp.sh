#!/bin/bash

# run_tests_assign2_1.sh
# Usage: bash run_tests_assign2_1.sh
#
# Runs the OpenMP wave simulation for:
# 10^3, 10^4, 10^5, 10^6, 10^7 points
# with 1000 time steps and 512 OpenMP threads.

STEPS=1000
OMP_THREADS=512

# Problem sizes
sizes=(1000 10000 100000 1000000 10000000)

echo "Running OpenMP wave equation benchmarks..."
echo "Timesteps: $STEPS"
echo "OpenMP threads: $OMP_THREADS"
echo "============================================"

export OMP_NUM_THREADS=$OMP_THREADS
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

for N in "${sizes[@]}"; do
    echo ""
    echo ">>> Running N=$N"

    prun -np 1 -native "-C TitanRTX" ./assign2_1 $N $STEPS $OMP_THREADS
done

echo ""
echo "All tests completed."
