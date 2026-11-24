///|
test "csc csr_to_csc basic columns" {
  let dense = [[1.0, 0.0, 2.0], [0.0, 3.0, 0.0]]
  let csc = @core.csr_to_csc(@core.from_dense(dense, 0.0))

  assert_eq(csc.rows, 2)
  assert_eq(csc.cols, 3)
  assert_eq(csc.values, [1.0, 3.0, 2.0])
  assert_eq(csc.row_indices, [0, 1, 0])
  assert_eq(csc.col_ptr, [0, 1, 2, 3])
}

///|
test "csc csr round trip preserves dense matrix" {
  let dense = [[1.0, 0.0, 2.0, 0.0], [0.0, 3.0, 0.0, 0.0], [4.0, 0.0, 0.0, 5.0]]
  let csc = @core.csr_to_csc(@core.from_dense(dense, 0.0))
  let restored = @core.csc_to_csr(csc)

  assert_eq(@core.to_dense(restored, 0.0), dense)
}

///|
test "csc coo round trip preserves dense matrix" {
  let dense = [[1.0, 0.0, 2.0, 0.0], [0.0, 3.0, 0.0, 0.0], [4.0, 0.0, 0.0, 5.0]]
  let csc = @core.csr_to_csc(@core.from_dense(dense, 0.0))
  let restored = @core.coo_to_csc(@core.csc_to_coo(csc))

  assert_eq(@core.to_dense(@core.csc_to_csr(restored), 0.0), dense)
}

///|
test "csc from_coo sorts and merges duplicate coordinates" {
  let coo = @core.CooMatrix::{
    values: [2.0, 1.0, 3.0, 4.0],
    row_indices: [1, 0, 0, 1],
    col_indices: [2, 1, 0, 2],
    rows: 2,
    cols: 3,
  }
  let csc = @core.coo_to_csc(coo)

  assert_eq(csc.values, [3.0, 1.0, 6.0])
  assert_eq(csc.row_indices, [0, 0, 1])
  assert_eq(csc.col_ptr, [0, 1, 2, 3])
  assert_eq(@core.to_dense(@core.csc_to_csr(csc), 0.0), [
    [3.0, 1.0, 0.0],
    [0.0, 0.0, 6.0],
  ])
}

///|
test "csc coo round trip preserves shape with empty trailing columns" {
  let csc = @core.CscMatrix::{
    values: [1.0, 2.0, 3.0],
    row_indices: [0, 2, 1],
    col_ptr: [0, 1, 1, 3, 3],
    rows: 3,
    cols: 4,
  }
  let coo = @core.csc_to_coo(csc)

  assert_eq(coo.rows, 3)
  assert_eq(coo.cols, 4)
  let restored = @core.coo_to_csc(coo)
  assert_eq(restored.values, [1.0, 3.0, 2.0])
  assert_eq(restored.row_indices, [0, 1, 2])
  assert_eq(restored.col_ptr, [0, 1, 1, 3, 3])
}

///|
test "csc int round trip" {
  let dense = [[1, 0, 2], [0, 3, 0]]
  let restored = @core.csc_to_csr(@core.csr_to_csc(@core.from_dense(dense, 0)))

  assert_eq(@core.to_dense(restored, 0), dense)
}
