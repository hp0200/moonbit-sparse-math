///|
fn basic_ops_assert_valid_csr(csr : @core.SparseMatrix[Double]) -> Unit raise {
  let rows = csr.row_ptr.length() - 1
  assert_eq(csr.row_ptr[0], 0)
  assert_eq(csr.values.length(), csr.col_indices.length())
  assert_eq(csr.row_ptr[rows], csr.values.length())
  for row = 0; row < rows; row = row + 1 {
    let start = csr.row_ptr[row]
    let end = csr.row_ptr[row + 1]
    assert_eq(start <= end, true)
    for k = start; k < end; k = k + 1 {
      assert_eq(csr.values[k] != 0.0, true)
      if k + 1 < end {
        assert_eq(csr.col_indices[k] < csr.col_indices[k + 1], true)
      }
    }
  }
}

///|
fn basic_ops_expect_error(
  result : Result[@core.SparseMatrix[Double], String],
) -> Unit raise {
  match result {
    Ok(_) => panic()
    Err(message) => assert_eq(message.length() > 0, true)
  }
}

///|
test "add merges overlapping structure" {
  let a = @core.from_dense([[1.0, 2.0, 0.0], [0.0, 3.0, 4.0]], 0.0)
  let b = @core.from_dense([[4.0, 5.0, 6.0], [7.0, 8.0, 9.0]], 0.0)
  let result = @ops.add(a, b).unwrap()

  assert_eq(result.values, [5.0, 7.0, 6.0, 7.0, 11.0, 13.0])
  assert_eq(result.col_indices, [0, 1, 2, 0, 1, 2])
  assert_eq(result.row_ptr, [0, 3, 6])
  basic_ops_assert_valid_csr(result)
}

///|
test "add cancels exact zeros and rejects dimension mismatch" {
  let a = @core.from_dense([[1.0, 2.0], [3.0, 4.0]], 0.0)
  let b = @core.from_dense([[-1.0, -2.0], [0.0, -4.0]], 0.0)
  let result = @ops.add(a, b).unwrap()

  assert_eq(result.values, [3.0])
  assert_eq(result.col_indices, [0])
  assert_eq(result.row_ptr, [0, 0, 1])
  basic_ops_assert_valid_csr(result)

  let different = @core.from_dense([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], 0.0)
  basic_ops_expect_error(@ops.add(a, different))
}

///|
test "scale handles nonzero, zero, and malformed stored rows" {
  let a = @core.from_dense([[1.0, 0.0, -2.0], [0.0, 3.0, 0.0]], 0.0)
  let scaled = @ops.scale(a, -2.0)
  assert_eq(scaled.values, [-2.0, 4.0, -6.0])
  assert_eq(scaled.col_indices, [0, 2, 1])
  assert_eq(scaled.row_ptr, [0, 2, 3])
  basic_ops_assert_valid_csr(scaled)

  let zeroed = @ops.scale(a, 0.0)
  assert_eq(zeroed.values, [])
  assert_eq(zeroed.row_ptr, [0, 0, 0])
  basic_ops_assert_valid_csr(zeroed)

  let raw : @core.SparseMatrix[Double] = @core.SparseMatrix::{
    values: [1.0, 2.0, 3.0, 0.0],
    col_indices: [1, 0, 1, 0],
    row_ptr: [0, 3, 4],
  }
  let normalized = @ops.scale(raw, 2.0)
  assert_eq(normalized.values, [4.0, 8.0])
  assert_eq(normalized.col_indices, [0, 1])
  assert_eq(normalized.row_ptr, [0, 2, 2])
  basic_ops_assert_valid_csr(normalized)
}

///|
test "elementwise_mul keeps only common nonzero structure" {
  let a = @core.from_dense([[1.0, 0.0, 2.0], [0.0, 3.0, 0.0]], 0.0)
  let b = @core.from_dense([[4.0, 5.0, 1.0], [6.0, 7.0, 2.0]], 0.0)
  let result = @ops.elementwise_mul(a, b).unwrap()

  assert_eq(result.values, [4.0, 2.0, 21.0])
  assert_eq(result.col_indices, [0, 2, 1])
  assert_eq(result.row_ptr, [0, 2, 3])
  basic_ops_assert_valid_csr(result)

  let different = @core.from_dense([[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]], 0.0)
  basic_ops_expect_error(@ops.elementwise_mul(a, different))
}

///|
test "add and elementwise_mul normalize duplicate and zero storage" {
  let raw : @core.SparseMatrix[Double] = @core.SparseMatrix::{
    values: [1.0, 2.0, 0.0, 4.0],
    col_indices: [0, 0, 0, 1],
    row_ptr: [0, 2, 4],
  }
  let b = @core.from_dense([[5.0, 0.0], [0.0, 6.0]], 0.0)

  let sum = @ops.add(raw, b).unwrap()
  assert_eq(sum.values, [8.0, 10.0])
  assert_eq(sum.col_indices, [0, 1])
  assert_eq(sum.row_ptr, [0, 1, 2])
  basic_ops_assert_valid_csr(sum)

  let product = @ops.elementwise_mul(raw, b).unwrap()
  assert_eq(product.values, [15.0, 24.0])
  assert_eq(product.col_indices, [0, 1])
  assert_eq(product.row_ptr, [0, 1, 2])
  basic_ops_assert_valid_csr(product)
}

///|
test "diag_scale scales columns and validates diagonal length" {
  let a = @core.from_dense([[1.0, 2.0], [3.0, 4.0]], 0.0)
  let result = @ops.diag_scale(a, [2.0, 0.0]).unwrap()

  assert_eq(result.values, [2.0, 6.0])
  assert_eq(result.col_indices, [0, 0])
  assert_eq(result.row_ptr, [0, 1, 2])
  basic_ops_assert_valid_csr(result)
  basic_ops_expect_error(@ops.diag_scale(a, [2.0]))
}

///|
test "get_row_slice extracts head, middle, and tail intervals" {
  let a = @core.from_dense(
    [[1.0, 0.0, 2.0], [0.0, 3.0, 0.0], [4.0, 0.0, 5.0], [0.0, 6.0, 7.0]],
    0.0,
  )

  let middle = @ops.get_row_slice(a, 1, 3).unwrap()
  assert_eq(@core.to_dense(middle, 0.0), [[0.0, 3.0, 0.0], [4.0, 0.0, 5.0]])
  basic_ops_assert_valid_csr(middle)

  let head = @ops.get_row_slice(a, 0, 1).unwrap()
  assert_eq(@core.to_dense(head, 0.0), [[1.0, 0.0, 2.0]])
  basic_ops_assert_valid_csr(head)

  let tail = @ops.get_row_slice(a, 2, 4).unwrap()
  assert_eq(@core.to_dense(tail, 0.0), [[4.0, 0.0, 5.0], [0.0, 6.0, 7.0]])
  basic_ops_assert_valid_csr(tail)

  let empty = @ops.get_row_slice(a, 2, 2).unwrap()
  assert_eq(empty.row_ptr, [0])
  assert_eq(empty.values, [])
  basic_ops_assert_valid_csr(empty)
}

///|
test "get_row_slice rejects invalid intervals" {
  let a = @core.from_dense([[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]], 0.0)

  basic_ops_expect_error(@ops.get_row_slice(a, -1, 2))
  basic_ops_expect_error(@ops.get_row_slice(a, 0, 4))
  basic_ops_expect_error(@ops.get_row_slice(a, 2, 1))
}
