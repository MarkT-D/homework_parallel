#!/bin/bash

OUTPUT="blocksize.csv"
echo "N,steps,block_size,time" > $OUTPUT

N=1000000
STEPS=1000
BLOCKSIZES=(32 64 128 256 512 1024)

for B in "${BLOCKSIZES[@]}"; do
    echo "Running block_size = $B..."

    RESULT=$(prun -np 1 -native "-C TitanRTX" ./assign2_1 $N $STEPS $B | grep "avg")

    TIME=$(echo $RESULT | grep -Eo 'avg = *[0-9]+\.[0-9]+' | awk '{print $3}')

    echo "$N,$STEPS,$B,$TIME" >> $OUTPUT
done

echo "Done! Results saved to $OUTPUT"
