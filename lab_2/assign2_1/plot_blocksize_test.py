import pandas as pd
import matplotlib.pyplot as plt

# Load CSV file
csv_file = "blocksize.csv"  # change to your CSV filename
data = pd.read_csv(csv_file)

# Check data
print(data)

# Plot: block_size vs time
plt.figure(figsize=(8,5))
plt.plot(data['block_size'], data['time'], marker='o', linestyle='-', color='b')

# Add labels and title
plt.xlabel("Block Size")
plt.ylabel("Execution Time (s)")
plt.title("Block Size Impact on Execution Time")
plt.grid(True)
plt.xticks(data['block_size'])  # show all block sizes as x-ticks

# Save plot
plt.savefig("blocksize_plot.png", dpi=300)
plt.show()
