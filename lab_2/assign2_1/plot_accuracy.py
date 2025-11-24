import numpy as np
import matplotlib.pyplot as plt
import csv

# ---------------------------------------------
# Read accuracy.csv
# ---------------------------------------------
filename = "accuracy.csv"

Ns = []
errors = []

with open(filename, "r") as f:
    reader = csv.DictReader(f)
    for row in reader:
        N = int(row["N"])
        err = row["max_abs_error"]
        if err != "ERROR":
            errors.append(float(err))
            Ns.append(N)
        else:
            errors.append(np.nan)
            Ns.append(N)

# ---------------------------------------------
# Plot
# ---------------------------------------------
plt.figure(figsize=(8, 5))

plt.plot(Ns, errors, marker="o", linestyle="-")
plt.xscale("log")
plt.yscale("log")

plt.xlabel("Problem size (N)")
plt.ylabel("Max absolute error")
plt.title("CUDA vs Sequential Accuracy t_max=100")
plt.grid(True, which="both", linestyle="--", linewidth=0.5)

plt.savefig("accuracy_plot.png", dpi=150)
plt.show()

print("Saved plot to accuracy_plot.png")
