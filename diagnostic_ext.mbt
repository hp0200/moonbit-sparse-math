pub fn estimate_conditioning(csr : SparseMatrix) -> String {
  let rows = csr.row_ptr.length() - 1

  // Infinity norm: the maximum absolute row sum.
  let mut max_norm = 0.0
  for i = 0; i < rows; i = i + 1 {
    let mut row_sum = 0.0
    for k = csr.row_ptr[i]; k < csr.row_ptr[i + 1]; k = k + 1 {
      row_sum = row_sum + csr.values[k].abs()
    }
    if row_sum > max_norm {
      max_norm = row_sum
    }
  }

  // Strict diagonal dominance implies good conditioning.
  if is_diagonally_dominant(csr) {
    return "Good"
  }

  let eps = 1.0e-12
  let off_diag_ratio = 10.0

  // Otherwise check for a near-zero diagonal, or off-diagonal entries
  // that overwhelm the diagonal entry in any row.
  for i = 0; i < rows; i = i + 1 {
    let mut diag_val = 0.0
    let mut sum_off_diag = 0.0
    for k = csr.row_ptr[i]; k < csr.row_ptr[i + 1]; k = k + 1 {
      let col = csr.col_indices[k]
      let val = csr.values[k]
      if col == i {
        diag_val = val
      } else {
        sum_off_diag = sum_off_diag + val.abs()
      }
    }

    let abs_diag = diag_val.abs()
    if abs_diag < eps || sum_off_diag > abs_diag * off_diag_ratio {
      return "Ill-conditioned (Warning)"
    }
  }

  "Moderate"
}