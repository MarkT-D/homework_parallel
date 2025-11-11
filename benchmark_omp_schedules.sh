#!/usr/bin/env bash
set -euo pipefail

# --- You MUST point BIN to your OpenMP binary (assignment 1.2) ---
BIN="${BIN:-./assign_1_2_framework/assign1_2}"   # e.g., BIN=./a1_2/assign1_2

# Initial condition used for all runs
INIT="${INIT:-sinfull}"

# What schedules to test:
#   - add/remove as you like. Each entry is "env_value  tag"
SCHEDULES=(
  "static,4096     static4k"
  "static,16384    static16k"
  "static,65536    static65k"
  "dynamic,1024    dynamic1k"
  "dynamic,4096    dynamic4k"
  "dynamic,16384   dynamic16k"
  "guided,1024     guided1k"
  "guided,4096     guided4k"
  "guided,16384    guided16k"
)

# CSV basename (files become results_<tag>.csv)
OUT_BASE="${OUT_BASE:-results}"

# Pin threads to cores for stability
export OMP_PROC_BIND=close
export OMP_PLACES=cores
export OMP_DISPLAY_ENV=FALSE

# Sanity: need benchmark_prun.sh next to this script (or set BENCH path)
BENCH="${BENCH:-./benchmark_prun.sh}"
if [[ ! -x "$BENCH" ]]; then
  echo "ERROR: cannot find executable $BENCH" >&2
  exit 1
fi

# Check binary
if [[ ! -x "$BIN" ]]; then
  echo "ERROR: binary not found or not executable: ${BIN}" >&2
  exit 1
fi

echo "Using BIN=$BIN, INIT=$INIT"
echo "Running schedules:"
printf '  - %s\n' "${SCHEDULES[@]}"

for pair in "${SCHEDULES[@]}"; do
  sched=$(awk '{print $1}' <<<"$pair")
  tag=$(awk '{print $2}' <<<"$pair")
  export OMP_SCHEDULE="$sched"
  CSV="${OUT_BASE}_${tag}.csv"
  echo
  echo "=== OMP_SCHEDULE='$sched'  -> CSV=$CSV ==="
  CSV="$CSV" BIN="$BIN" INIT="$INIT" "$BENCH"
done

echo
echo "Done. Generated CSV files:"
ls -1 ${OUT_BASE}_*.csv 2>/dev/null || true
