# SPA SpGEMM Benchmark

## Environment

- Date: 2026-11-20
- OS: Windows 11
- CPU: Intel Core i7-14650HX
- MoonBit: `moon 0.1.20261102 (ea07287 2026-11-02)`
- Command: `moon bench --release`

## Workload

- Input: two independently generated CSR matrices of size `1000 x 1000`
- Density: `1%` per matrix (empty rows receive one diagonal entry)
- Values: pseudo-random `Double` values
- Output: CSR matrix
- Comparison:
  - `matmul_map`: per-row product list followed by sort and reduce
  - `matmul_spa`: SPA accumulator over touched output columns

## Results

```text
name                   time (mean +/- sigma)     range (min ... max)
matmul_map             17.94 ms +/- 4.68 ms       14.34 ms ... 25.30 ms   in 10 x  7 runs
matmul_spa              5.53 ms +/- 55.60 us        5.46 ms ...  5.63 ms   in 10 x 19 runs
```

The SPA implementation is approximately `3.2x` faster than the map-and-sort
implementation on this workload. Both variants produce the same CSR output,
which is also covered by the unit and randomized dense cross-check tests.
