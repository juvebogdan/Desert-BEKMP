import os

# Initialize a list to hold the sums of the last two numbers for each valid line
sums = []

# Process each file in the range
for i in range(40):  # 0 to 39
    filename = f"tracefilenode{i}.txt"
    if os.path.exists(filename):
        with open(filename, 'r') as file:
            for line in file:
                parts = line.strip().split()
                if len(parts) > 5 and parts[5] == '5':  # Check if sixth number is 5
                    # Convert the last two numbers to floats and add them
                    sum_last_two = float(parts[-2]) + float(parts[-1])
                    sums.append(sum_last_two)

# Remove the top 10% of entries
sums_sorted = sorted(sums)
to_remove = int(len(sums_sorted) * 0.0)
sums_filtered = sums_sorted[:-to_remove] if to_remove > 0 else sums_sorted

# Calculate the average of the remaining sums
average_sum = sum(sums_filtered) / len(sums_filtered) if sums_filtered else 0

print(f"Average of sums: {average_sum}")
