import pandas as pd
import matplotlib.pyplot as plt

# Load CUDA
cuda = pd.read_csv("scalability.csv")
cuda['N'] = cuda['N'].astype(int)
cuda_time = cuda['time']

# Load Pthreads
pth = pd.read_csv("results_assign1_1.csv")
pth['N'] = pth['N'].astype(int)
pth_time = pd.to_numeric(pth['normalized_time'], errors='coerce')

# Load OpenMP
omp = pd.read_csv("results_openmp_assign1_2.csv")
omp['N'] = omp['N'].astype(int)
omp_time = pd.to_numeric(omp['normalized_time'], errors='coerce')

# --- Combined Plot ---
plt.figure(figsize=(9,6))

plt.plot(cuda['N'], cuda_time, marker='o', label='CUDA')
plt.plot(pth['N'], pth_time, marker='s', label='Pthreads')
plt.plot(omp['N'], omp_time, marker='^', label='OpenMP')

plt.xscale('log')
plt.yscale('log')

plt.xlabel("Number of Amplitude Points (N)")
plt.ylabel("Execution Time (s)")
plt.title("Wave Equation Execution Time – CUDA vs Pthreads vs OpenMP")

plt.grid(True, which="both", linestyle="--", linewidth=0.5)
plt.legend()
plt.tight_layout()

plt.savefig("comparison_plot.png", dpi=300)
plt.show()
