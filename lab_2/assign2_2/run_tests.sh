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
# Create these yourself (see section below).
FILES=(
  "tiny.data"      # ~2 KB
  "small.data"     # ~10 KB
  "medium1.data"   # ~50 KB
  "medium2.data"   # ~200 KB
  "large1.data"    # ~1 MB
  "large2.data"    # ~5 MB
  "huge1.data"     # ~10 MB
  "huge2.data"     # ~50 MB
)

# Keys:
# - Caesar: single key
# - Vigenère: multi-key "FEMBOY" = 5 4 12 1 14 24
CAESAR_KEY="3"
VIGENERE_KEY="5 4 12 1 14 24"

#########################
# INIT CSV FILES
#########################

echo "file,key_type,key,bytes,enc_seq,enc_kernel,enc_mem,dec_seq,dec_kernel,dec_mem" > "$CAESAR_CSV"

echo "source_file,which_file,key_type,key,bytes,checksum_cuda,checksum_seq,time_kernel,time_memory,time_seq" > "$CHECKSUM_CSV"

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
    # try Linux stat first, fallback to macOS style if needed
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
    echo "Size: $bytes bytes"
    echo "=================================================="

    # Prepare original.data
    cp "$src_file" original.data

    #########################
    # RUN CAESAR/VIGENERE (GPU job)
    #########################

    echo ">> Running caesar on GPU..."
    caesar_out=$(prun -v -np 1 -native "$GPU_NATIVE" "$CAESAR" $key_args 2>&1)

    # Extract times
    enc_seq=$(echo "$caesar_out" | awk '/Encryption \(sequential\)/    {print $(NF-1)}')
    enc_kernel=$(echo "$caesar_out" | awk '/Encrypt \(kernel\)/       {print $(NF-1)}')
    enc_mem=$(echo "$caesar_out" | awk '/Encrypt \(memory\)/          {print $(NF-1)}')
    dec_seq=$(echo "$caesar_out" | awk '/Decryption \(sequential\)/   {print $(NF-1)}')
    dec_kernel=$(echo "$caesar_out" | awk '/Decrypt \(kernel\)/       {print $(NF-1)}')
    dec_mem=$(echo "$caesar_out" | awk '/Decrypt \(memory\)/          {print $(NF-1)}')

    echo "$src_file,$key_type,\"$key_args\",$bytes,$enc_seq,$enc_kernel,$enc_mem,$dec_seq,$dec_kernel,$dec_mem" >> "$CAESAR_CSV"

    #########################
    # RUN CHECKSUMS (original + cuda)
    #########################
    for which in original.data cuda.data; do
      echo ">> Running checksum on $which (both: cuda + seq)..."
      cs_out=$(prun -v -np 1 -native "$GPU_NATIVE" "$CHECKSUM" "$which" both 2>&1)

      cuda_sum=$(echo "$cs_out" | awk '/CUDA checksum/        {print $3}')
      seq_sum=$(echo "$cs_out"  | awk '/Sequential checksum/ {print $3}')

      time_kernel=$(echo "$cs_out" | awk '/Kernel:/                 {print $(NF-1)}')
      time_memory=$(echo "$cs_out" | awk '/Memory:/                 {print $(NF-1)}')
      time_seq=$(echo "$cs_out"    | awk '/Checksum \(sequential\)/ {print $(NF-1)}')

      echo "$src_file,$which,$key_type,\"$key_args\",$bytes,$cuda_sum,$seq_sum,$time_kernel,$time_memory,$time_seq" >> "$CHECKSUM_CSV"
    done

    echo ">> Done with '$src_file' [$key_type]"
    echo
  done
done

echo "All tests finished."
echo "Results written to:"
echo "  - $CAESAR_CSV"
echo "  - $CHECKSUM_CSV"
