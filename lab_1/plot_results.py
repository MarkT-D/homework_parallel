#!/usr/bin/env python3
import sys, csv
from collections import defaultdict, OrderedDict
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

csv_path = sys.argv[1] if len(sys.argv) > 1 else "results_omp_custom_static_16384.csv"
out_png  = sys.argv[2] if len(sys.argv) > 2 else "speedup_3.png"

rows = []
with open(csv_path, newline="") as f:
    r = csv.DictReader(f)
    for row in r:
        row["i_max"]    = int(row["i_max"])
        row["t_max"]    = int(row["t_max"])
        row["threads"]  = int(row["threads"])
        row["time_sec"] = float(row["time_sec"])
        rows.append(row)

# For each i_max and thread count, keep the *best* (minimal) time over trials
best_time = defaultdict(dict)  # best_time[i_max][threads] = min time_sec

for row in rows:
    i_max   = row["i_max"]
    threads = row["threads"]
    t       = row["time_sec"]
    prev    = best_time[i_max].get(threads)
    if prev is None or t < prev:
        best_time[i_max][threads] = t

# Build sorted per-size lists (threads increasing, best times)
by_size = {}
for i_max, th_dict in best_time.items():
    lst = sorted(th_dict.items(), key=lambda x: x[0])  # (threads, time)
    by_size[i_max] = lst

# Compute speedups using best times
speedups = OrderedDict()
for i_max, lst in sorted(by_size.items()):
    # lst: list of (threads, time)
    base = next((t for th, t in lst if th == 1), None)
    if base is None:
        continue
    speedups[i_max] = [(th, base / t) for th, t in lst]

print("Speedup table (best of trials):")
for i_max, sp in speedups.items():
    print(f"i_max={i_max}")
    for th, s in sp:
        print(f"  {th:2d} -> {s:8.3f}")
    print()

plt.figure(figsize=(8, 6))
for i_max, sp in speedups.items():
    th = [t for t, _ in sp]
    su = [s for _, s in sp]
    plt.plot(th, su, marker="o", label=f"i_max={i_max:,}")

if speedups:
    mt = max(max(t for t, _ in sp) for sp in speedups.values())
    plt.plot([1, mt], [1, mt], "--", label="ideal", linewidth=1)

plt.xlabel("Threads")
plt.ylabel("Speedup (T1 / Tp)")
plt.title("Wave Equation: Speedup vs Threads (best of trials)")
plt.grid(True)
plt.legend()

# Limit y-axis to 0..10
plt.ylim(0, 10)

plt.tight_layout()
plt.savefig(out_png, dpi=150)
print(f"Wrote {out_png}")
