///|
pub using @core {
  type CooMatrix,
  type CscMatrix,
  type SparseError,
  type SparseMatrix,
  coo_to_csc,
  csc_to_coo,
  csc_to_csr,
  csr_to_csc,
  from_coo,
  from_dense,
  spmv,
  spmv_simd,
  to_coo,
  to_dense,
  transpose,
}

///|
pub using @ops {matmul}

///|
pub using @solvers {cg_solve, pcg_solve}

///|
pub using @algebra {estimate_conditioning, is_diagonally_dominant, to_csc}

///|
pub using @wasm {run_sir_web_zero_copy, sir_result_count, sir_result_ptr}
