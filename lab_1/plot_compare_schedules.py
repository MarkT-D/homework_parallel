#!/usr/bin/env python3
import sys, os, csv, glob
from collections import defaultdict
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

def usage():
    print("Usage: plot_compare_schedules.py <csv_glob1> [<csv_glob2> ...] "
          "[--out OUTPREFIX] [--no-ideal] [--percent] [--ylim ymin:ymax] [--plot-norm]")
    sys.exit(1)

# ---- args ----
if len(sys.argv) < 2:
    usage()

args = sys.argv[1:]
out_prefix = "speedup_sched"
show_ideal = True
as_percent = False
manual_ylim = None
plot_norm = False

i = 0
globs = []
while i < len(args):
    a = args[i]
    if a == "--out":
        out_prefix = args[i+1]; i += 2
    elif a == "--no-ideal":
        show_ideal = False; i += 1
    elif a == "--percent":
        as_percent = True; i += 1
    elif a == "--ylim":
        manual_ylim = args[i+1]; i += 2
    elif a == "--plot-norm":
        plot_norm = True; i += 1
    else:
        globs.append(a); i += 1

# ---- expand paths ----
csv_paths = []
for pattern in globs:
    hits = glob.glob(pattern)
    csv_paths.extend(sorted(hits) if hits else [pattern])

if not csv_paths:
    print("No CSV files matched."); sys.exit(1)

# ---- load CSVs & compute normalized ----
# data[label] = list of dict rows
data = {}
for p in csv_paths:
    label = os.path.splitext(os.path.basename(p))[0]
    rows = []
    with open(p, newline="") as f:
        r = csv.DictReader(f)
        for row in r:
            try:
                i_max   = int(row["i_max"])
                t_max   = int(row["t_max"])
                threads = int(row["threads"])
                time_s  = float(row["time_sec"])
            except Exception:
                continue
            if i_max <= 0 or t_max <= 0 or time_s <= 0: 
                continue
            norm = time_s / (i_max * t_max)
            rows.append({"i_max":i_max,"t_max":t_max,"threads":threads,
                         "time_sec":time_s,"normalized":norm})
    if rows:
        data[label] = rows

if not data:
    print("No readable rows found. Check your CSVs."); sys.exit(1)

# ---- write merged normalized CSV ----
merged_csv = f"{out_prefix}_normalized.csv"
with open(merged_csv, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["label","i_max","t_max","threads","time_sec","normalized"])
    for label, rows in data.items():
        for r in rows:
            w.writerow([label, r["i_max"], r["t_max"], r["threads"],
                        f"{r['time_sec']:.6f}", f"{r['normalized']:.9e}"])
print(f"Wrote {merged_csv}")

# ---- build speedup maps ----
speedups = {}                 # speedups[label][i_max] = [(threads, speedup)]
all_imax = set()
imax_tmax_map = defaultdict(list)

for label, rows in data.items():
    by_size = defaultdict(list)
    for r in rows:
        by_size[r["i_max"]].append(r)
        imax_tmax_map[r["i_max"]].append(r["t_max"])
    label_map = {}
    for i_max, lst in by_size.items():
        lst = sorted(lst, key=lambda x: x["threads"])
        base = next((x["time_sec"] for x in lst if x["threads"] == 1), None)
        if not base or base <= 0: 
            continue
        sp = [(x["threads"], base / x["time_sec"]) for x in lst if x["time_sec"] > 0]
        if sp:
            label_map[i_max] = sp
            all_imax.add(i_max)
    if label_map:
        speedups[label] = label_map

def tmax_str(i_max):
    vals = sorted(set(imax_tmax_map.get(i_max, [])))
    if not vals: return ""
    return f"t_max={vals[0]:,}" if len(vals)==1 else f"t_max=[{vals[0]:,}..{vals[-1]:,}]"

# ---- plot speedup per i_max ----
for i_max in sorted(all_imax):
    plt.figure(figsize=(8,6))
    plotted = False; all_y = []
    for label, spmap in speedups.items():
        if i_max not in spmap: continue
        th = [t for t,_ in spmap[i_max]]
        su = [s for _,s in spmap[i_max]]
        if as_percent: su = [(v-1.0)*100.0 for v in su]
        all_y.extend(su)
        plt.plot(th, su, marker="o", linewidth=1.8, label=label)
        plotted = True
    if not plotted: 
        plt.close(); continue

    plt.xlabel("Threads")
    plt.ylabel("Improvement over 1 thread (%)" if as_percent else "Speedup (T1 / Tp)")
    plt.title(f"Wave Speedup vs Threads  (i_max={i_max:,}, {tmax_str(i_max)})")
    plt.grid(True); plt.legend(fontsize=8, ncol=1)

    if manual_ylim:
        try:
            y0,y1 = manual_ylim.split(":"); plt.ylim(float(y0), float(y1))
        except Exception: pass
    else:
        y = np.array(all_y, float)
        ymin, ymax = np.nanmin(y), np.nanmax(y)
        if as_percent:
            rng = max(1.0, ymax-ymin); pad = 0.1*rng
            plt.ylim(ymin-pad, ymax+pad)
        else:
            plt.ylim(0.0, max(1.2, ymax*1.1))

    if show_ideal:
        ax = plt.gca(); x2 = int(ax.get_xlim()[1])
        if x2 >= 1:
            xs = [1,x2]; ys = [0,(x2-1)*100.0] if as_percent else [1,x2]
            plt.plot(xs, ys, "--", linewidth=1.2, color="tab:gray", alpha=0.7, label="ideal")
            plt.legend(fontsize=8, ncol=1)

    out = f"{out_prefix}_speedup_imax_{i_max}.png"
    plt.tight_layout(); plt.savefig(out, dpi=150); plt.close()
    print(f"Wrote {out}")

# ---- optional: normalized time plots ----
if plot_norm:
    # group normalized by label & size
    normmap = defaultdict(lambda: defaultdict(list))
    for label, rows in data.items():
        by_size = defaultdict(list)
        for r in rows: by_size[r["i_max"]].append(r)
        for i_max, lst in by_size.items():
            lst = sorted(lst, key=lambda x: x["threads"])
            normmap[label][i_max] = [(x["threads"], x["normalized"]) for x in lst]

    for i_max in sorted(set(k for m in normmap.values() for k in m.keys())):
        plt.figure(figsize=(8,6))
        plotted = False; all_y = []
        for label in sorted(normmap.keys()):
            if i_max not in normmap[label]: continue
            th = [t for t,_ in normmap[label][i_max]]
            ny = [v for _,v in normmap[label][i_max]]
            all_y.extend(ny)
            plt.plot(th, ny, marker="o", linewidth=1.8, label=label)
            plotted = True
        if not plotted: 
            plt.close(); continue

        plt.xlabel("Threads")
        plt.ylabel("Normalized time [s / (i_max · t_max)]")
        plt.title(f"Normalized Time vs Threads  (i_max={i_max:,}, {tmax_str(i_max)})")
        plt.grid(True); plt.legend(fontsize=8, ncol=1)

        y = np.array(all_y, float)
        ymin, ymax = np.nanmin(y), np.nanmax(y)
        rng = max(1e-12, ymax-ymin); pad = 0.1*rng
        plt.ylim(max(0.0, ymin-pad), ymax+pad)

        out = f"{out_prefix}_norm_imax_{i_max}.png"
        plt.tight_layout(); plt.savefig(out, dpi=150); plt.close()
        print(f"Wrote {out}")
