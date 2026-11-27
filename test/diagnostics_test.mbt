///|
test "is_symmetric accepts a symmetric sparse matrix" {
  let csr = @core.from_dense(
    [[2.0, 1.0, 0.0], [1.0, 3.0, 4.0], [0.0, 4.0, 5.0]],
    0.0,
  )
  assert_eq(@algebra.is_symmetric(csr), true)
}

///|
test "is_symmetric rejects an asymmetric matrix" {
  let csr = @core.from_dense([[1.0, 2.0], [0.0, 1.0]], 0.0)
  assert_eq(@algebra.is_symmetric(csr), false)
}

///|
test "is_symmetric rejects a non-square matrix" {
  let csr = @core.from_dense([[1.0, 0.0, 2.0], [0.0, 1.0, 0.0]], 0.0)
  assert_eq(@algebra.is_symmetric(csr), false)
}

///|
test "is_symmetric ignores explicitly stored zero entries" {
  let csr : @core.SparseMatrix[Double] = @core.SparseMatrix::{
    values: [2.0, 0.0, 3.0],
    col_indices: [0, 1, 1],
    row_ptr: [0, 2, 3],
  }
  assert_eq(@algebra.is_symmetric(csr), true)
}

///|
test "is_symmetric rejects non-finite values" {
  let csr = @core.from_dense([[1.0, 0.0 / 0.0], [0.0, 1.0]], 0.0)
  assert_eq(@algebra.is_symmetric(csr), false)
}

///|
test "is_positive_definite accepts a symmetric positive definite matrix" {
  let csr = @core.from_dense([[4.0, 1.0], [1.0, 3.0]], 0.0)
  assert_eq(@algebra.is_positive_definite(csr), true)
}

///|
test "is_positive_definite rejects a positive semidefinite matrix" {
  let csr = @core.from_dense([[1.0, 1.0], [1.0, 1.0]], 0.0)
  assert_eq(@algebra.is_positive_definite(csr), false)
}

///|
test "is_positive_definite rejects a non-symmetric matrix" {
  let csr = @core.from_dense([[2.0, 1.0], [0.0, 2.0]], 0.0)
  assert_eq(@algebra.is_positive_definite(csr), false)
}

///|
test "is_positive_definite rejects a non-square matrix" {
  let csr = @core.from_dense([[2.0, 0.0, 1.0], [0.0, 2.0, 0.0]], 0.0)
  assert_eq(@algebra.is_positive_definite(csr), false)
}

///|
test "is_positive_definite handles a single node matrix" {
  let csr = @core.from_dense([[5.0]], 0.0)
  assert_eq(@algebra.is_positive_definite(csr), true)
}

///|
test "is_positive_definite rejects a negative diagonal" {
  let csr = @core.from_dense([[-1.0, 0.0], [0.0, 2.0]], 0.0)
  assert_eq(@algebra.is_positive_definite(csr), false)
}

///|
test "is_positive_definite keeps relative precision for tiny matrices" {
  let csr = @core.from_dense([[1.0e-20, 0.0], [0.0, 2.0e-20]], 0.0)
  assert_eq(@algebra.is_positive_definite(csr), true)
}

///|
test "get_connected_components finds disconnected groups and an isolated node" {
  let csr = @core.from_dense(
    [
      [1.0, 1.0, 0.0, 0.0, 0.0],
      [1.0, 1.0, 0.0, 0.0, 0.0],
      [0.0, 0.0, 2.0, 0.0, 0.0],
      [0.0, 0.0, 0.0, 3.0, 1.0],
      [0.0, 0.0, 0.0, 1.0, 3.0],
    ],
    0.0,
  )
  assert_eq(@algebra.get_connected_components(csr), [0, 0, 1, 2, 2])
}

///|
test "get_connected_components treats directed edges as undirected" {
  let csr = @core.from_dense(
    [[0.0, 1.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 1.0]],
    0.0,
  )
  assert_eq(@algebra.get_connected_components(csr), [0, 0, 1])
}

///|
test "get_connected_components handles a single node" {
  let csr = @core.from_dense([[7.0]], 0.0)
  assert_eq(@algebra.get_connected_components(csr), [0])
}

///|
test "get_connected_components handles an empty matrix" {
  let empty : Array[Array[Double]] = []
  let csr = @core.from_dense(empty, 0.0)
  assert_eq(@algebra.get_connected_components(csr), [])
}

///|
test "get_connected_components ignores explicitly stored zero entries" {
  let csr : @core.SparseMatrix[Double] = @core.SparseMatrix::{
    values: [1.0, 0.0, 1.0, 1.0, 1.0],
    col_indices: [0, 1, 1, 2, 3],
    row_ptr: [0, 2, 3, 4, 5],
  }
  assert_eq(@algebra.get_connected_components(csr), [0, 1, 2, 3])
}
