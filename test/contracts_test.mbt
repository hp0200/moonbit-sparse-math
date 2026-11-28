///|
fn contract_test_matrix() -> @core.SparseMatrix[Double] {
  @core.from_dense([[4.0, 1.0, 0.0], [1.0, 3.0, 1.0], [0.0, 1.0, 2.0]], 0.0)
}

///|
test "contracts: permutation predicate rejects invalid permutations" {
  assert_true(@contracts.is_permutation([0, 2, 1]))
  assert_false(@contracts.is_permutation([0, 0, 1]))
  assert_false(@contracts.is_permutation([0, 1, 3]))
  assert_false(@contracts.is_permutation([0, -1, 2]))
}

///|
test "contracts: COO conversion and transpose preserve shape invariants" {
  let matrix = contract_test_matrix()
  let coo = @contracts.csr_to_coo(matrix)
  assert_eq(coo.rows, 3)
  assert_eq(coo.cols, 3)
  assert_eq(coo.values.length(), matrix.values.length())

  let transposed = @contracts.transpose(matrix)
  assert_eq(transposed.row_ptr.length(), 4)
  assert_eq(transposed.values.length(), matrix.values.length())
}

///|
test "contracts: permutation and RCM preserve nonzero count and bandwidth" {
  let matrix = contract_test_matrix()
  let permuted = @contracts.permute(matrix, [0, 2, 1])
  assert_eq(permuted.row_ptr.length(), 4)
  assert_eq(permuted.values.length(), matrix.values.length())

  let ordering = @contracts.rcm(matrix)
  assert_true(@contracts.is_permutation(ordering))
  assert_true(
    @contracts.bandwidth(@contracts.permute(matrix, ordering)) <=
    @contracts.bandwidth(matrix),
  )
}

///|
test "contracts: symmetry and positive-definiteness diagnostics agree" {
  let matrix = contract_test_matrix()
  assert_true(@contracts.is_symmetric(matrix))
  assert_true(@contracts.is_positive_definite(matrix))

  let asymmetric = @core.from_dense([[2.0, 1.0], [0.0, 2.0]], 0.0)
  assert_false(@contracts.is_symmetric(asymmetric))
  assert_false(@contracts.is_positive_definite(asymmetric))
}

///|
test "contracts: PCG respects bounds and reduces residual" {
  let matrix = contract_test_matrix()
  let b = [1.0, 2.0, 3.0]
  let x0 = [0.0, 0.0, 0.0]
  let outcome = match @contracts.pcg(matrix, b, x0) {
    Ok(value) => value
    Err(message) => fail("PCG contract failed: \{message}")
  }
  assert_true(outcome.iterations <= @contracts.MAX_ITERATIONS)
  assert_true(outcome.residual_norm >= 0.0)
  let ax = @core.spmv(matrix, outcome.solution).unwrap()
  for i = 0; i < b.length(); i = i + 1 {
    assert_true((ax[i] - b[i]).abs() < 1.0e-8)
  }
}

///|
test "contracts: PCG handles an already converged initial guess" {
  let matrix = @core.from_dense([[2.0, 0.0], [0.0, 3.0]], 0.0)
  let b = [2.0, 3.0]
  let x0 = [1.0, 1.0]
  let outcome = match @contracts.pcg(matrix, b, x0) {
    Ok(value) => value
    Err(message) => fail("PCG early-exit contract failed: \{message}")
  }
  assert_eq(outcome.iterations, 0)
  assert_true(outcome.residual_norm >= 0.0)
  assert_true(outcome.residual_norm < 1.0e-12)
  assert_eq(outcome.solution, x0)
}
