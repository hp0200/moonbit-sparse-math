# Changelog

## [0.3.0] - 2026-11-24
### Added
- Support for `Float` and `Int` types via generic `Ring` trait implementation.
- COO (Coordinate) and CSC (Compressed Sparse Column) matrix formats.
- Native FFI zero-copy memory sharing for WebAssembly.
- SIMD (V128) vectorization for SpMV, improving performance by ~17%.

### Changed
- **BREAKING**: Restructured project directory into `src/core`, `src/ops`, `src/solvers`, `src/algebra`, and `src/wasm`.
- Integrated with Luna-Flow ecosystem for generic algebra operations.
- Optimized SpGEMM using Sparse Accumulator (SPA) for zero-allocation.

### Fixed
- Robust error handling for singular or non-positive-definite matrices in the PCG solver.
