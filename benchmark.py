import time
import random

known_tablets = list(range(100000))
connected_ids = list(range(90000, 90100))

# Baseline: Array.contains inside loop
start = time.time()
result = next((t for t in known_tablets if t in connected_ids), None)
end = time.time()
print(f"Baseline (Array): {(end - start) * 1000:.3f} ms")

# Optimized: Set lookup
start = time.time()
connected_set = set(connected_ids)
result = next((t for t in known_tablets if t in connected_set), None)
end = time.time()
print(f"Optimized (Set): {(end - start) * 1000:.3f} ms")
