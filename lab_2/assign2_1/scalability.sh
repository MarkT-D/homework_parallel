#!/bin/bash

OUTPUT="scalability.csv"
echo "N,steps,block_size,time" > $OUTPUT

SIZES=(1000 10000 100000 1000000 10000000)
STEPS=1000
BLOCK=512

for N in "${SIZES[@]}"; do
    echo "Running N=$N..."

    # Run on the GPU and capture only the "avg =" line
    RESULT=$(prun -np 1 -native "-C TitanRTX" ./assign2_1 $N $STEPS $BLOCK | grep "avg")

    # Extract the numeric value after avg =
    TIME=$(echo $RESULT | grep -Eo 'avg = *[0-9]+\.[0-9]+' | awk '{print $3}')

    # Append to CSV
    echo "$N,$STEPS,$BLOCK,$TIME" >> $OUTPUT
done

echo "Done! Results saved to $OUTPUT"
