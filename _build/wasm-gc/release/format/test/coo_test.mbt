///|
test "coo to_coo basic coordinates" {
  let dense = [[1.0, 0.0, 2.0], [0.0, 3.0, 0.0]]
  let coo = @core.to_coo(@core.from_dense(dense, 0.0))

  assert_eq(coo.rows, 2)
  assert_eq(coo.cols, 3)
  assert_eq(coo.values, [1.0, 2.0, 3.0])
  assert_eq(coo.row_indices, [0, 0, 1])
  assert_eq(coo.col_indices, [0, 2, 1])
}

///|
test "coo csr round trip preserves dense matrix" {
  let dense = [[1.0, 0.0, 2.0, 0.0], [0.0, 3.0, 0.0, 0.0], [4.0, 0.0, 0.0, 5.0]]
  let csr = @core.from_dense(dense, 0.0)
  let restored = @core.from_coo(@core.to_coo(csr))

  assert_eq(@core.to_dense(restored, 0.0), dense)
}

///|
test "coo from_coo sorts and merges duplicate coordinates" {
  let coo = @core.CooMatrix::{
    values: [2.0, 1.0, 3.0, 4.0],
    row_indices: [1, 0, 0, 1],
    col_indices: [2, 1, 0, 2],
    rows: 3,
    cols: 3,
  }
  let csr = @core.from_coo(coo)

  assert_eq(csr.values, [3.0, 1.0, 6.0])
  assert_eq(csr.col_indices, [0, 1, 2])
  assert_eq(csr.row_ptr, [0, 2, 3, 3])
  assert_eq(@core.to_dense(csr, 0.0), [
    [3.0, 1.0, 0.0],
    [0.0, 0.0, 6.0],
    [0.0, 0.0, 0.0],
  ])
}

///|
test "coo int round trip" {
  let dense = [[1, 0, 2], [0, 3, 0]]
  let restored = @core.from_coo(@core.to_coo(@core.from_dense(dense, 0)))

  assert_eq(@core.to_dense(restored, 0), dense)
}
