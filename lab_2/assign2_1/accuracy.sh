#!/bin/bash

OUTPUT="accuracy.csv"
echo "N,steps,block_size,max_abs_error" > $OUTPUT

N=1000000
STEPS=1000
BLOCK=512

echo "Running CUDA version..."
prun -np 1 -native "-C TitanRTX" ./assign2_1 $N $STEPS $BLOCK
mv result.txt result_cuda.txt

echo "Running sequential version..."
./assign2_seq $N $STEPS
mv result.txt result_seq.txt

# Compare arrays in Python
ERROR=$(python3 - <<EOF
import numpy as np

cuda = np.loadtxt("result_cuda.txt")
seq  = np.loadtxt("result_seq.txt")

print(np.max(np.abs(cuda - seq)))
EOF
)

echo "$N,$STEPS,$BLOCK,$ERROR" >> $OUTPUT
echo "Done! Saved to $OUTPUT"
