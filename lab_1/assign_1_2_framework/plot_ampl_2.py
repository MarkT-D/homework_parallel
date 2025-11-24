import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("results_openmp_assign1_2.csv")
df['N'] = df['N'].astype(int)
df['normalized_time'] = pd.to_numeric(df['normalized_time'], errors='coerce')

plt.figure(figsize=(8,5))
plt.plot(df['N'], df['normalized_time'], marker='o', label='Normalized Time')
plt.xscale('log')
plt.yscale('log')
plt.xlabel('Problem Size N')
plt.ylabel('Normalized Time (s)')
plt.title('Wave Simulation Benchmark')
plt.grid(True, which="both", ls="--", lw=0.5)
plt.legend()
plt.tight_layout()
plt.show()
