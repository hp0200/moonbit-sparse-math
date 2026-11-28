# Changelog

## [0.4.0] - 2026-11-28
### Added
- Matrix Market (`.mtx`) coordinate-format read/write with automatic CSR conversion.
- Structural diagnostics for symmetry, positive definiteness, and connected components.
- Reverse Cuthill-McKee (RCM) matrix reordering for reduced bandwidth.
- Core sparse operators: addition, scalar scaling, Hadamard product, diagonal scaling, and row slicing.
- Bidirectional conversion between CSR matrices and directed adjacency lists.
- Self-contained `Complex` scalar support with a complete `Field` instance for complex SpMV.

## [0.3.1] - 2026-11-24
### Fixed
- Added `readme` field to `moon.mod` for better display on mooncakes.io.
- Updated version badge in README.

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
