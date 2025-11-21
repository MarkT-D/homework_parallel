#!/bin/bash

# --- CONFIG -------------------------------
OUTPUT="accuracy.csv"
SIZES=(1000 10000 100000 1000000)   # i_max values
TMAX=1000                           # number of timesteps
BLOCK=512                           # thread block size
# ------------------------------------------

echo "N,steps,block_size,max_abs_error" > $OUTPUT

echo "Running accuracy tests..."
echo

for N in "${SIZES[@]}"; do
    echo "----------------------------------------------"
    echo "Testing i_max = $N"
    echo "----------------------------------------------"

    # --------------------------
    # Run the CUDA version
    # --------------------------
    echo "[CUDA] Running on GPU..."
    prun -np 1 -native "-C TitanRTX" ./assign2_1 $N $TMAX $BLOCK

    # GPU output is in result.txt
    mv result.txt cuda_result_$N.txt

    # Sequential output is in seq_result.txt
    mv seq_result.txt seq_result_$N.txt

    # --------------------------
    # Compare CUDA vs Sequential
    # --------------------------
    ERROR=$(python3 - <<EOF
import numpy as np
cuda = np.loadtxt("cuda_result_${N}.txt")
seq  = np.loadtxt("seq_result_${N}.txt")
print(np.max(np.abs(cuda - seq)))
EOF
)

    echo "Error for N=$N: $ERROR"
    echo "$N,$TMAX,$BLOCK,$ERROR" >> $OUTPUT

done

echo
echo "Done! Accuracy results saved to $OUTPUT"
