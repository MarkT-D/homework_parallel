#!/bin/bash

# CSV output file
OUTPUT="accuracy.csv"
echo "N,steps,block_size,max_abs_error" > $OUTPUT

# Parameters
N=1000000
STEPS=1000
BLOCK=512

# Step 1: Compile sequential code if not already compiled
if [ ! -f assign2_seq ]; then
    echo "Compiling sequential code..."
    gcc -O2 -o assign2_seq assign2_seq.c -lm
    if [ $? -ne 0 ]; then
        echo "Compilation failed!"
        exit 1
    fi
fi

# Step 2: Run CUDA version
echo "Running CUDA version..."
prun -np 1 -native "-C TitanRTX" ./assign2_1 $N $STEPS $BLOCK
if [ ! -f result.txt ]; then
    echo "CUDA program did not produce result.txt!"
    exit 1
fi
mv result.txt result_cuda.txt

# Step 3: Run sequential version
echo "Running sequential version..."
./assign2_seq $N $STEPS 1
if [ ! -f result.txt ]; then
    echo "Sequential program did not produce result.txt!"
    exit 1
fi
mv result.txt result_seq.txt

# Step 4: Compare using Python / NumPy
# Make sure NumPy is available on DAS-5
if ! python3 -c "import numpy" &> /dev/null; then
    echo "NumPy not found. Load a module with: module load py-numpy"
    exit 1
fi

ERROR=$(python3 - <<EOF
import numpy as np

cuda = np.loadtxt("result_cuda.txt")
seq  = np.loadtxt("result_seq.txt")

print(np.max(np.abs(cuda - seq)))
EOF
)

# Step 5: Write to CSV
echo "$N,$STEPS,$BLOCK,$ERROR" >> $OUTPUT
echo "Done! Results saved to $OUTPUT"
