#!/bin/bash

# ===================================================
# DAS5 Accuracy Testing Script for GPU assignment
# Fixed version — no invalid TRES/GRES options.
# ===================================================

OUTPUT="accuracy.csv"
echo "N,steps,block_size,max_abs_error" > $OUTPUT

STEPS=1000
BLOCK=512

# Array sizes to test
SIZES=(1000 10000 100000 1000000 10000000)

echo "Running accuracy tests..."

for N in "${SIZES[@]}"; do
    echo "----------------------------------------------"
    echo "Testing i_max = $N"
    echo "----------------------------------------------"

    # Correct DAS5 GPU command (no --gres)
    prun -v -np 1 -native "-C TitanRTX" ./assign2_1 $N $STEPS $BLOCK

    # Check if output files exist
    if [[ ! -f result_cuda.txt ]] || [[ ! -f result.txt ]]; then
        echo "ERROR: Missing result_cuda.txt or result.txt for N=$N"
        echo "$N,$STEPS,$BLOCK,ERROR" >> $OUTPUT
        continue
    fi

    # Compare arrays using Python
    ERROR=$(python3 - <<EOF
import numpy as np
cuda = np.loadtxt("result.txt")
seq  = np.loadtxt("result_cuda.txt")
print(np.max(np.abs(cuda - seq)))
EOF
)

    echo "$N,$STEPS,$BLOCK,$ERROR" >> $OUTPUT
    echo "Error for N=$N: $ERROR"

    # Clean for next run
    rm -f result.txt result_cuda.txt
done

echo ""
echo "Done! Accuracy results saved to accuracy.csv"
