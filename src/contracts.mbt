///|
pub const MAX_ITERATIONS : Int32 = 1000

///|
pub(all) struct PcgOutcome {
  solution : Array[Double]
  iterations : Int32
  residual_norm : Double
}

///|
fn contract_rows(matrix : @core.SparseMatrix[Double]) -> Int32 {
  matrix.row_ptr.length() - 1
}

///|
fn contract_cols(matrix : @core.SparseMatrix[Double]) -> Int32 {
  let rows = contract_rows(matrix)
  let mut maximum = -1
  for col in matrix.col_indices {
    if col > maximum {
      maximum = col
    }
  }
  if maximum < 0 {
    rows
  } else {
    maximum + 1
  }
}

///|
fn contract_nnz(matrix : @core.SparseMatrix[Double]) -> Int32 {
  matrix.values.length()
}

///|
fn contract_assert(condition : Bool, message : String) -> Unit {
  if !condition {
    println("contract violation: \{message}")
    panic()
  }
}

///|
fn contract_value_at(
  matrix : @core.SparseMatrix[Double],
  row : Int32,
  col : Int32,
) -> Double {
  let mut value = 0.0
  for pos = matrix.row_ptr[row]; pos < matrix.row_ptr[row + 1]; pos = pos + 1 {
    if matrix.col_indices[pos] == col {
      value = value + matrix.values[pos]
    }
  }
  value
}

///|
fn contract_close(left : Double, right : Double) -> Bool {
  let mut scale = left.abs()
  if right.abs() > scale {
    scale = right.abs()
  }
  if scale < 1.0 {
    scale = 1.0
  }
  (left - right).abs() <= 1.0e-12 * scale
}

///|
/// Runtime predicate for a permutation of `0..perm.length()`.
pub fn is_permutation(perm : Array[Int32]) -> Bool {
  let n = perm.length()
  let seen = Array::make(n, false)
  for value in perm {
    if value < 0 || value >= n || seen[value] {
      return false
    }
    seen[value] = true
  }
  true
}

///|
/// Runtime bandwidth of a square CSR pattern: `max |row - col|` over stored
/// coordinates. An empty matrix has bandwidth zero.
pub fn bandwidth(matrix : @core.SparseMatrix[Double]) -> Int32 {
  let rows = contract_rows(matrix)
  let mut bandwidth = 0
  for row = 0; row < rows; row = row + 1 {
    for pos = matrix.row_ptr[row]; pos < matrix.row_ptr[row + 1]; pos = pos + 1 {
      let col = matrix.col_indices[pos]
      let distance = if col >= row { col - row } else { row - col }
      if distance > bandwidth {
        bandwidth = distance
      }
    }
  }
  bandwidth
}

///|
/// Runtime predicate matching the library's Cholesky-based SPD diagnostic.
pub fn is_positive_definite(matrix : @core.SparseMatrix[Double]) -> Bool {
  @algebra.is_positive_definite(matrix)
}

///|
/// Contract C1: CSR to COO conversion preserves dimensions and nonzero count.
///
/// TODO: 需人工证明. `moon prove` currently does not model `Array<T>`, which is
/// the production CSR storage type.
pub fn csr_to_coo(
  matrix : @core.SparseMatrix[Double],
) -> @core.CooMatrix[Double] {
  let rows = contract_rows(matrix)
  let cols = contract_cols(matrix)
  let nnz = contract_nnz(matrix)
  let result = @core.to_coo(matrix)
  contract_assert(result.rows == rows, "C1: COO row count changed")
  contract_assert(result.cols == cols, "C1: COO column count changed")
  contract_assert(
    result.values.length() == nnz,
    "C1: COO nonzero count changed",
  )
  contract_assert(
    result.row_indices.length() == nnz && result.col_indices.length() == nnz,
    "C1: COO coordinate arrays disagree with values",
  )
  result
}

///|
/// Contract C2: transpose exchanges dimensions while preserving nonzero count.
///
/// TODO: 需人工证明. `moon prove` currently does not model `Array<T>`.
pub fn transpose(
  matrix : @core.SparseMatrix[Double],
) -> @core.SparseMatrix[Double] {
  let rows = contract_rows(matrix)
  let cols = contract_cols(matrix)
  let nnz = contract_nnz(matrix)
  let result = @core.transpose(matrix)
  contract_assert(contract_rows(result) == cols, "C2: transposed row count")
  contract_assert(contract_cols(result) == rows, "C2: transposed column count")
  contract_assert(contract_nnz(result) == nnz, "C2: transposed nonzero count")
  result
}

///|
/// Contract C3: permutation preserves dimensions and nonzero count.
///
/// TODO: 需人工证明. The prover cannot currently consume the `Array`-backed
/// production representation.
pub fn permute(
  matrix : @core.SparseMatrix[Double],
  perm : Array[Int32],
) -> @core.SparseMatrix[Double] {
  let rows = contract_rows(matrix)
  let cols = contract_cols(matrix)
  let nnz = contract_nnz(matrix)
  contract_assert(perm.length() == rows, "C3: permutation length mismatch")
  contract_assert(is_permutation(perm), "C3: argument is not a permutation")
  let result = @core.apply_ordering(matrix, perm)
  contract_assert(contract_rows(result) == rows, "C3: permuted row count")
  contract_assert(contract_cols(result) == cols, "C3: permuted column count")
  contract_assert(contract_nnz(result) == nnz, "C3: permuted nonzero count")
  result
}

///|
/// Contract C4: RCM returns a permutation and does not increase bandwidth.
///
/// TODO: 需人工证明. This proof requires an `Array`-level graph invariant that
/// the current proof backend does not model.
pub fn rcm(matrix : @core.SparseMatrix[Double]) -> Array[Int32] {
  contract_assert(@algebra.is_symmetric(matrix), "C4: matrix must be symmetric")
  let before = bandwidth(matrix)
  let result = @core.rcm_ordering(matrix)
  contract_assert(is_permutation(result), "C4: RCM result is not a permutation")
  let after = bandwidth(permute(matrix, result))
  contract_assert(after <= before, "C4: RCM increased matrix bandwidth")
  result
}

///|
/// Contract C5: a positive symmetry diagnostic has no false positives.
///
/// TODO: 需人工证明. `moon prove` does not model the `Array`-backed CSR.
pub fn is_symmetric(matrix : @core.SparseMatrix[Double]) -> Bool {
  let result = @algebra.is_symmetric(matrix)
  if result {
    let rows = contract_rows(matrix)
    let cols = contract_cols(matrix)
    for row = 0; row < rows; row = row + 1 {
      for col = 0; col < cols; col = col + 1 {
        contract_assert(
          contract_close(
            contract_value_at(matrix, row, col),
            contract_value_at(matrix, col, row),
          ),
          "C5: symmetry diagnostic returned true for asymmetric values",
        )
      }
    }
  }
  result
}

///|
fn contract_dot(left : Array[Double], right : Array[Double]) -> Double {
  let mut sum = 0.0
  for i = 0; i < left.length(); i = i + 1 {
    sum = sum + left[i] * right[i]
  }
  sum
}

///|
/// Contract C6: PCG with an explicit initial guess.
///
/// The returned iteration count never exceeds `MAX_ITERATIONS`, and the final
/// residual norm is non-negative. On failure, an `Err` is returned rather than
/// a misleading result.
///
/// TODO: 需人工证明. Floating-point PCG requires a numerical-analysis model
/// beyond the current proof backend.
pub fn pcg(
  a : @core.SparseMatrix[Double],
  b : Array[Double],
  x0 : Array[Double],
) -> Result[PcgOutcome, String] {
  let rows = contract_rows(a)
  if b.length() != rows || x0.length() != rows {
    return Err("C6: vector dimension mismatch")
  }
  if !is_symmetric(a) || !is_positive_definite(a) {
    return Err("C6: matrix must be symmetric positive definite")
  }

  let diagonal_inverse = Array::make(rows, 0.0)
  for row = 0; row < rows; row = row + 1 {
    let mut diagonal_found = false
    let mut diagonal = 0.0
    for pos = a.row_ptr[row]; pos < a.row_ptr[row + 1]; pos = pos + 1 {
      if a.col_indices[pos] == row {
        diagonal = a.values[pos]
        diagonal_found = true
      }
    }
    if !diagonal_found || diagonal <= 0.0 {
      return Err("C6: matrix has a non-positive diagonal pivot")
    }
    diagonal_inverse[row] = 1.0 / diagonal
  }

  let ax0 = match @core.spmv(a, x0) {
    Ok(value) => value
    Err(_) => return Err("C6: spmv rejected the initial guess")
  }
  let x = Array::make(rows, 0.0)
  let r = Array::make(rows, 0.0)
  let z = Array::make(rows, 0.0)
  let p = Array::make(rows, 0.0)
  for i = 0; i < rows; i = i + 1 {
    x[i] = x0[i]
    r[i] = b[i] - ax0[i]
    z[i] = diagonal_inverse[i] * r[i]
    p[i] = z[i]
  }

  let tolerance = 1.0e-10
  let b_norm_sq = contract_dot(b, b)
  let scale = if b_norm_sq > 1.0 { b_norm_sq } else { 1.0 }
  let threshold = tolerance * tolerance * scale
  let mut residual_sq = contract_dot(r, r)
  let mut rz = contract_dot(r, z)
  let mut iterations : Int32 = 0

  if residual_sq <= threshold {
    let outcome = PcgOutcome::{
      solution: x,
      iterations,
      residual_norm: residual_sq.sqrt(),
    }
    contract_assert(
      outcome.iterations <= MAX_ITERATIONS,
      "C6: iteration bound exceeded",
    )
    contract_assert(outcome.residual_norm >= 0.0, "C6: negative residual norm")
    return Ok(outcome)
  }
  if rz <= 0.0 {
    return Err("C6: preconditioned residual is not positive")
  }

  while iterations < MAX_ITERATIONS {
    let ap = match @core.spmv(a, p) {
      Ok(value) => value
      Err(_) => return Err("C6: spmv rejected a search direction")
    }
    let pap = contract_dot(p, ap)
    if pap <= 0.0 {
      return Err("C6: search direction is not positive definite")
    }
    let alpha = rz / pap
    for i = 0; i < rows; i = i + 1 {
      x[i] = x[i] + alpha * p[i]
      r[i] = r[i] - alpha * ap[i]
    }
    residual_sq = contract_dot(r, r)
    if residual_sq <= threshold {
      let outcome = PcgOutcome::{
        solution: x,
        iterations,
        residual_norm: residual_sq.sqrt(),
      }
      contract_assert(
        outcome.iterations <= MAX_ITERATIONS,
        "C6: iteration bound exceeded",
      )
      contract_assert(
        outcome.residual_norm >= 0.0,
        "C6: negative residual norm",
      )
      return Ok(outcome)
    }
    for i = 0; i < rows; i = i + 1 {
      z[i] = diagonal_inverse[i] * r[i]
    }
    let rz_new = contract_dot(r, z)
    if rz_new <= 0.0 {
      return Err("C6: preconditioned residual became non-positive")
    }
    let beta = rz_new / rz
    for i = 0; i < rows; i = i + 1 {
      p[i] = z[i] + beta * p[i]
    }
    rz = rz_new
    iterations = iterations + 1
  }
  Err("C6: iteration limit reached")
}
