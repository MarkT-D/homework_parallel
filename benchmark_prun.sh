#!/usr/bin/env bash
set -euo pipefail

# ---- CONFIG (edit here or override via env) ----
BIN="${BIN:-./assign1_1}"           # or ./assign1_2
INIT="${INIT:-sinfull}"             # sin | sinfull | gauss | file ...
THREADS=(1 2 4 6 8 12 14 16)
SIZES=(1000 10000 100000 1000000 10000000)

TARGET_MIN=${TARGET_MIN:-10}        # seconds
TARGET_MAX=${TARGET_MAX:-100}       # seconds
CSV="${CSV:-results_wave.csv}"

# For OpenMP runs (assign1_2), you can export these before calling the script:
# export OMP_SCHEDULE="static,16384"
# export OMP_NUM_THREADS is NOT used here; we pass thread count as argv[3].

# ---- helpers ----
run_one() {
  local i_max="$1" t_max="$2" nthr="$3"
  # -np 1 = single process; adjust with queue/account flags if your DAS-5 needs them
  prun -v -np 1 "${BIN}" "${i_max}" "${t_max}" "${nthr}" "${INIT}"
}

extract_time() {
  awk '/^Took /{t=$2} END{print t+0}'
}

# ---- check binary ----
if [[ ! -x "$BIN" ]]; then
  echo "ERROR: binary not found or not executable: ${BIN}" >&2
  exit 1
fi

echo "i_max,t_max,threads,time_sec" > "$CSV"

for i_max in "${SIZES[@]}"; do
  echo "== Size i_max=${i_max} =="

  # 1) tune t_max using 1 thread to hit ~TARGET_MIN..TARGET_MAX
  t_max=256
  tries=0
  while :; do
    echo "  Tuning: t_max=${t_max}, threads=1 ..."
    out="$(run_one "$i_max" "$t_max" 1 | tee /dev/stderr)"
    time_sec="$(printf "%s\n" "$out" | extract_time || true)"

    if [[ -z "${time_sec}" ]]; then
      echo "  WARNING: couldn't parse time; using current t_max=${t_max}" >&2
      break
    fi

    if (( $(echo "$time_sec >= $TARGET_MIN" | bc -l) )); then
      break
    fi

    t_max=$(( t_max * 2 ))
    tries=$((tries+1))
    if (( tries > 20 )); then
      echo "  WARNING: tuning tries exceeded; proceeding with t_max=${t_max}" >&2
      break
    fi
  done

  # refine once if we overshot
  if [[ -n "${time_sec:-}" ]] && (( $(echo "$time_sec > $TARGET_MAX" | bc -l) )); then
    scaled=$(python3 - <<PY
t=${t_max}
best=${time_sec}
target=${TARGET_MIN}
print(max(1, int(t*target/best)))
PY
)
    echo "  Refining: scaled t_max=${scaled}"
    out="$(run_one "$i_max" "$scaled" 1 | tee /dev/stderr)"
    time_sec="$(printf "%s\n" "$out" | extract_time || true)"
    if [[ -n "${time_sec}" ]]; then
      t_max="${scaled}"
    fi
  fi

  echo "  Chosen t_max=${t_max} for i_max=${i_max}"

  # 2) sweep thread counts with fixed t_max
  for nthr in "${THREADS[@]}"; do
    echo "  Run: threads=${nthr}"
    out="$(run_one "$i_max" "$t_max" "$nthr" | tee /dev/stderr)"
    time_sec="$(printf "%s\n" "$out" | extract_time || true)"
    if [[ -z "${time_sec}" ]]; then
      echo "    WARNING: couldn't parse time; skipping." >&2
      continue
    fi
    echo "${i_max},${t_max},${nthr},${time_sec}" >> "$CSV"
  done
done

echo "Wrote ${CSV}"
