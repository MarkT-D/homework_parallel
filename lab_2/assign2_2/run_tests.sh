#!/bin/bash
set -euo pipefail

#########################
# CONFIG
#########################

GPU_NATIVE="-C TitanX"

CAESAR="./caesar"
CHECKSUM="./checksum"

CAESAR_CSV="caesar_results.csv"
CHECKSUM_CSV="checksum_results.csv"

# 8 input files with increasing sizes.
FILES=(
  "tiny.data"      # ~2 KB
  "small.data"     # ~10 KB
  "medium1.data"   # ~50 KB
  "medium2.data"   # ~200 KB
  "large1.data"    # ~1 MB
  "large2.data"    # ~5 MB
  "huge1.data"     # ~50 MB
  "huge2.data"     # ~500 MB
)

# Keys:
# - Caesar: single key
# - Vigenère: multi-key "FEMBOY" = 5 4 12 1 14 24
CAESAR_KEY="3"
VIGENERE_KEY="5 4 12 1 14 24"

# Number of repeated runs per configuration
TRIALS=5

#########################
# HELPER: float addition
#########################
float_add() {
    awk -v a="$1" -v b="$2" 'BEGIN {printf "%.10f", a + b}'
}

float_div() {
    awk -v a="$1" -v b="$2" 'BEGIN {printf "%.6f", a / b}'
}

#########################
# INIT CSV FILES
#########################

echo "file,key_type,key,bytes,trials,enc_seq,enc_kernel,enc_mem,dec_seq,dec_kernel,dec_mem" > "$CAESAR_CSV"

echo "source_file,which_file,key_type,key,bytes,trials,checksum_cuda,checksum_seq,time_kernel,time_memory,time_seq" > "$CHECKSUM_CSV"

#########################
# MAIN LOOP
#########################

for src_file in "${FILES[@]}"; do
  if [[ ! -f "$src_file" ]]; then
    echo ">>> Skipping '$src_file' (file not found)"
    continue
  fi

  # determine file size in bytes
  if command -v stat >/dev/null 2>&1; then
    if bytes=$(stat -c%s "$src_file" 2>/dev/null); then
      :
    else
      bytes=$(stat -f%z "$src_file")
    fi
  else
    bytes=$(stat -f%z "$src_file")
  fi

  # For each file: run both Caesar and Vigenère
  for key_type in caesar vigenere; do
    if [[ "$key_type" == "caesar" ]]; then
      key_args="$CAESAR_KEY"
    else
      key_args="$VIGENERE_KEY"
    fi

    echo "=================================================="
    echo "File: $src_file | key_type: $key_type | key: $key_args"
    echo "Size: $bytes bytes | Trials: $TRIALS"
    echo "=================================================="

    # Prepare original.data
    cp "$src_file" original.data

    #########################
    # CAESAR/VIGENERE: run TRIALS times and average
    #########################

    enc_seq_sum=0
    enc_kernel_sum=0
    enc_mem_sum=0
    dec_seq_sum=0
    dec_kernel_sum=0
    dec_mem_sum=0

    for t in $(seq 1 "$TRIALS"); do
      echo ">> [caesar] Trial $t/$TRIALS ..."
      caesar_out=$(prun -v -np 1 -native "$GPU_NATIVE" "$CAESAR" $key_args 2>&1)

      enc_seq=$(echo "$caesar_out" | awk '/Encryption \(sequential\)/    {print $(NF-1)}')
      enc_kernel=$(echo "$caesar_out" | awk '/Encrypt \(kernel\)/       {print $(NF-1)}')
      enc_mem=$(echo "$caesar_out" | awk '/Encrypt \(memory\)/          {print $(NF-1)}')
      dec_seq=$(echo "$caesar_out" | awk '/Decryption \(sequential\)/   {print $(NF-1)}')
      dec_kernel=$(echo "$caesar_out" | awk '/Decrypt \(kernel\)/       {print $(NF-1)}')
      dec_mem=$(echo "$caesar_out" | awk '/Decrypt \(memory\)/          {print $(NF-1)}')

      enc_seq_sum=$(float_add "$enc_seq_sum" "$enc_seq")
      enc_kernel_sum=$(float_add "$enc_kernel_sum" "$enc_kernel")
      enc_mem_sum=$(float_add "$enc_mem_sum" "$enc_mem")
      dec_seq_sum=$(float_add "$dec_seq_sum" "$dec_seq")
      dec_kernel_sum=$(float_add "$dec_kernel_sum" "$dec_kernel")
      dec_mem_sum=$(float_add "$dec_mem_sum" "$dec_mem")
    done

    enc_seq_avg=$(float_div "$enc_seq_sum" "$TRIALS")
    enc_kernel_avg=$(float_div "$enc_kernel_sum" "$TRIALS")
    enc_mem_avg=$(float_div "$enc_mem_sum" "$TRIALS")
    dec_seq_avg=$(float_div "$dec_seq_sum" "$TRIALS")
    dec_kernel_avg=$(float_div "$dec_kernel_sum" "$TRIALS")
    dec_mem_avg=$(float_div "$dec_mem_sum" "$TRIALS")

    echo "$src_file,$key_type,\"$key_args\",$bytes,$TRIALS,$enc_seq_avg,$enc_kernel_avg,$enc_mem_avg,$dec_seq_avg,$dec_kernel_avg,$dec_mem_avg" >> "$CAESAR_CSV"

    #########################
    # CHECKSUMS: original.data and cuda.data
    #########################

    for which in original.data cuda.data; do
      echo ">> [checksum] $which, key_type=$key_type ..."

      cs_kernel_sum=0
      cs_memory_sum=0
      cs_seq_sum=0
      last_cuda_sum=""
      last_seq_sum=""

      for t in $(seq 1 "$TRIALS"); do
        echo "   Trial $t/$TRIALS ..."
        cs_out=$(prun -v -np 1 -native "$GPU_NATIVE" "$CHECKSUM" "$which" both 2>&1)

        cuda_sum=$(echo "$cs_out" | awk '/CUDA checksum/        {print $3}')
        seq_sum=$(echo "$cs_out"  | awk '/Sequential checksum/ {print $3}')

        time_kernel=$(echo "$cs_out" | awk '/Kernel:/                 {print $(NF-1)}')
        time_memory=$(echo "$cs_out" | awk '/Memory:/                 {print $(NF-1)}')
        time_seq=$(echo "$cs_out"    | awk '/Checksum \(sequential\)/ {print $(NF-1)}')

        cs_kernel_sum=$(float_add "$cs_kernel_sum" "$time_kernel")
        cs_memory_sum=$(float_add "$cs_memory_sum" "$time_memory")
        cs_seq_sum=$(float_add "$cs_seq_sum" "$time_seq")

        last_cuda_sum="$cuda_sum"
        last_seq_sum="$seq_sum"
      done

      cs_kernel_avg=$(float_div "$cs_kernel_sum" "$TRIALS")
      cs_memory_avg=$(float_div "$cs_memory_sum" "$TRIALS")
      cs_seq_avg=$(float_div "$cs_seq_sum" "$TRIALS")

      echo "$src_file,$which,$key_type,\"$key_args\",$bytes,$TRIALS,$last_cuda_sum,$last_seq_sum,$cs_kernel_avg,$cs_memory_avg,$cs_seq_avg" >> "$CHECKSUM_CSV"
    done

    echo ">> Done with '$src_file' [$key_type]"
    echo
  done
done

echo "All tests finished."
echo "Results written to:"
echo "  - $CAESAR_CSV"
echo "  - $CHECKSUM_CSV"
