#!/bin/bash
set -euo pipefail

PROG_BLOCK=./assign3_1       # blocking (3.1)
PROG_NB=./assign3_1_nb       # non-blocking (3.2)

# Problem sizes: 1e3 .. 1e8
SIZES=(1000 10000 100000 1000000 10000000 100000000)


OUTFILE="bench_results.csv"

echo "prog,mode,nodes,ppn,total_procs,i_max,t_max,time_sec" > "$OUTFILE"

# ---------- progress bar setup ----------
runs_per_size=24                # 4 ppn * 2 progs + 4 nodes*2 progs + 4 nodes*2 progs = 24
num_sizes=${#SIZES[@]}
TOTAL_RUNS=$((runs_per_size * num_sizes))
CURRENT_RUN=0

progress_bar() {
    local curr=$1
    local total=$2
    local width=40

    local perc=$(( 100 * curr / total ))
    local fill=$(( width * curr / total ))

    # build bar
    local bar=""
    for ((i=0; i<fill; i++));   do bar+="#"; done
    for ((i=fill; i<width; i++)); do bar+="."; done

    echo -ne "\r[$bar] $curr/$total (${perc}%)"
}
# ----------------------------------------


run_case() {
    local prog="$1"
    local mode="$2"
    local nodes="$3"
    local ppn="$4"
    local imax="$5"
    local tmax="$6"

    # On DAS: prun -np <nodes> -<ppn>, total ranks = nodes * ppn
    local total=$((nodes * ppn))

    # Small status line (will scroll), main visual is the progress bar
    echo
    echo "Running $prog [$mode] i_max=$imax t_max=$tmax nodes=$nodes ppn=$ppn (total=$total)"

    out=$(prun -v -np "$nodes" -"$ppn" \
        -sge-script "$PRUN_ETC/prun-openmpi" \
        "$prog" "$imax" "$tmax" 2>/dev/null)

    # Extract 'Took X seconds' line and grab X
    time_sec=$(echo "$out" | awk '/^Took / {print $2}')

    if [[ -z "$time_sec" ]]; then
        echo "WARNING: could not parse time for $prog $mode i_max=$imax nodes=$nodes ppn=$ppn" >&2
        time_sec="NaN"
    fi

    echo "$prog,$mode,$nodes,$ppn,$total,$imax,$tmax,$time_sec" >> "$OUTFILE"

    # update progress
    CURRENT_RUN=$((CURRENT_RUN + 1))
    progress_bar "$CURRENT_RUN" "$TOTAL_RUNS"
}

for imax in "${SIZES[@]}"; do
    echo
    echo "=== Problem size i_max=$imax, t_max=$TMAX ==="

    # 1) Single-node scaling: up to 8 MPI processes on a single node
    #    nodes=1, ppn=1,2,4,8
    for ppn in 1 2 4 8; do
        run_case "$PROG_BLOCK" "block_1node" 1 "$ppn" "$imax" "$TMAX"
        run_case "$PROG_NB"    "nonblock_1node" 1 "$ppn" "$imax" "$TMAX"
    done

    # 2) Up to 8 nodes, single MPI process per node
    #    nodes = 1,2,4,8; ppn=1
    for nodes in 1 2 4 8; do
        run_case "$PROG_BLOCK" "block_1ppn" "$nodes" 1 "$imax" "$TMAX"
        run_case "$PROG_NB"    "nonblock_1ppn" "$nodes" 1 "$imax" "$TMAX"
    done

    # 3) Up to 8 nodes, 8 MPI processes per node
    #    nodes = 1,2,4,8; ppn=8 (total procs 8..64)
    for nodes in 1 2 4 8; do
        run_case "$PROG_BLOCK" "block_8ppn" "$nodes" 8 "$imax" "$TMAX"
        run_case "$PROG_NB"    "nonblock_8ppn" "$nodes" 8 "$imax" "$TMAX"
    done

done

echo
echo
echo "All done. Results in $OUTFILE"
