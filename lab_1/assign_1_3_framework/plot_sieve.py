#!/usr/bin/env python3
import sys
import pandas as pd
import matplotlib.pyplot as plt

def main():
    # Input / output
    csv_path = sys.argv[1] if len(sys.argv) > 1 else "sieve_times_full.csv"
    out_png  = sys.argv[2] if len(sys.argv) > 2 else "sieve_times_by_cores.png"

    # Read CSV
    df = pd.read_csv(csv_path)

    # Only keep actual compute rows (in case there are other modes)
    df = df[df["mode"] == "compute"].copy()

    # Use the median time per (N, cores) to reduce impact of outliers
    grouped = (
        df.groupby(["N", "cores"], as_index=False)["real_sec"]
          .median()
          .rename(columns={"real_sec": "med_sec"})
    )

    # Order cores in a sensible way if present
    preferred_order = ["0,2", "0,2,4,6", "0-7", "all"]
    cores_values = [c for c in preferred_order if c in grouped["cores"].unique()]
    # plus any unknown masks, sorted
    others = [c for c in sorted(grouped["cores"].unique()) if c not in cores_values]
    cores_values += others

    plt.figure(figsize=(8, 6))

    for cores in cores_values:
        sub = grouped[grouped["cores"] == cores].sort_values("N")
        if sub.empty:
            continue
        plt.plot(sub["N"], sub["med_sec"], marker="o", label=f"cores={cores}")

    plt.xlabel("N (number of primes requested)")
    plt.ylabel("Median time per run [s]")
    plt.title("Sieve: median runtime vs N for different core masks")
    plt.grid(True)
    plt.legend()
    plt.tight_layout()
    plt.savefig(out_png, dpi=150)
    print(f"Wrote {out_png}")

if __name__ == "__main__":
    main()
