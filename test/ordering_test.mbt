///|
fn rcm_bandwidth(csr : @core.SparseMatrix[Double]) -> Int32 {
  let rows = csr.row_ptr.length() - 1
  let mut bandwidth = 0
  for row = 0; row < rows; row = row + 1 {
    for k = csr.row_ptr[row]; k < csr.row_ptr[row + 1]; k = k + 1 {
      let col = csr.col_indices[k]
      let distance = if row > col { row - col } else { col - row }
      if distance > bandwidth {
        bandwidth = distance
      }
    }
  }
  bandwidth
}

///|
fn rcm_is_permutation(perm : Array[Int32], size : Int32) -> Bool {
  if perm.length() != size {
    return false
  }
  let seen = Array::make(size, false)
  for node in perm {
    if node < 0 || node >= size || seen[node] {
      return false
    }
    seen[node] = true
  }
  true
}

///|
fn rcm_scrambled_path_dense(nodes : Int32) -> Array[Array[Double]] {
  let labels : Array[Int32] = []
  for i = 0; i < nodes / 2; i = i + 1 {
    labels.push(i * 2)
  }
  for i = 0; i < nodes / 2; i = i + 1 {
    labels.push(i * 2 + 1)
  }
  let positions = Array::make(nodes, 0)
  for position = 0; position < nodes; position = position + 1 {
    positions[labels[position]] = position
  }

  let dense : Array[Array[Double]] = []
  for i = 0; i < nodes; i = i + 1 {
    dense.push(Array::make(nodes, 0.0))
  }
  for node = 0; node < nodes; node = node + 1 {
    let position = positions[node]
    dense[position][position] = 1.0
    if node + 1 < nodes {
      let next_position = positions[node + 1]
      dense[position][next_position] = 1.0
      dense[next_position][position] = 1.0
    }
  }
  dense
}

///|
test "rcm_ordering reduces bandwidth of a scrambled banded path" {
  let csr = @core.from_dense(rcm_scrambled_path_dense(20), 0.0)
  let original_bandwidth = rcm_bandwidth(csr)
  let perm = @core.rcm_ordering(csr)
  let reordered = @core.apply_ordering(csr, perm)
  let reordered_bandwidth = rcm_bandwidth(reordered)

  assert_eq(rcm_is_permutation(perm, 20), true)
  assert_eq(original_bandwidth > 5, true)
  assert_eq(reordered_bandwidth < original_bandwidth, true)
  assert_eq(reordered_bandwidth <= 2, true)
}

///|
test "apply_ordering preserves spmv under node permutation" {
  let dense = [
    [4.0, 1.0, 0.0, 0.0, 0.0, 0.0],
    [0.0, 5.0, 1.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 6.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 7.0, 1.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 8.0, 1.0],
    [1.0, 0.0, 0.0, 0.0, 0.0, 9.0],
  ]
  let csr = @core.from_dense(dense, 0.0)
  let perm = @core.rcm_ordering(csr)
  let reordered = @core.apply_ordering(csr, perm)
  let x = [1.0, -2.0, 3.0, -4.0, 5.0, -6.0]
  let x_perm : Array[Double] = []
  for i = 0; i < perm.length(); i = i + 1 {
    x_perm.push(x[perm[i]])
  }
  let y = @core.spmv(csr, x).unwrap()
  let y_perm = @core.spmv(reordered, x_perm).unwrap()

  for i = 0; i < perm.length(); i = i + 1 {
    assert_eq((y_perm[i] - y[perm[i]]).abs() < 1.0e-12, true)
  }
}

///|
test "apply_ordering emits sorted CSR columns and valid row pointers" {
  let csr = @core.from_dense(
    [[0.0, 1.0, 2.0], [3.0, 0.0, 4.0], [5.0, 6.0, 0.0]],
    0.0,
  )
  let reordered = @core.apply_ordering(csr, [2, 0, 1])

  assert_eq(reordered.row_ptr[0], 0)
  assert_eq(
    reordered.row_ptr[reordered.row_ptr.length() - 1],
    reordered.values.length(),
  )
  for row = 0; row < reordered.row_ptr.length() - 1; row = row + 1 {
    assert_eq(reordered.row_ptr[row] <= reordered.row_ptr[row + 1], true)
    for k = reordered.row_ptr[row]
        k + 1 < reordered.row_ptr[row + 1]
        k = k + 1 {
      assert_eq(reordered.col_indices[k] < reordered.col_indices[k + 1], true)
    }
  }
}

///|
test "rcm_ordering covers disconnected components and isolated nodes" {
  let csr = @core.from_dense(
    [
      [1.0, 1.0, 0.0, 0.0, 0.0],
      [1.0, 1.0, 0.0, 0.0, 0.0],
      [0.0, 0.0, 1.0, 1.0, 0.0],
      [0.0, 0.0, 1.0, 1.0, 0.0],
      [0.0, 0.0, 0.0, 0.0, 1.0],
    ],
    0.0,
  )
  let perm = @core.rcm_ordering(csr)
  assert_eq(rcm_is_permutation(perm, 5), true)
}

///|
test "rcm_ordering handles empty and single-node matrices" {
  let empty : Array[Array[Double]] = []
  assert_eq(@core.rcm_ordering(@core.from_dense(empty, 0.0)), [])
  assert_eq(@core.rcm_ordering(@core.from_dense([[3.0]], 0.0)), [0])
}

///|
test "apply_ordering rejects invalid permutations safely" {
  let csr = @core.from_dense([[1.0, 2.0], [3.0, 4.0]], 0.0)
  let invalid_duplicate = @core.apply_ordering(csr, [0, 0])
  let invalid_range = @core.apply_ordering(csr, [0, 2])

  assert_eq(invalid_duplicate.row_ptr, [0])
  assert_eq(invalid_duplicate.values, [])
  assert_eq(invalid_range.row_ptr, [0])
  assert_eq(invalid_range.values, [])
}

///|
test "apply_ordering merges duplicate CSR coordinates" {
  let csr : @core.SparseMatrix[Double] = @core.SparseMatrix::{
    values: [1.0, 2.0],
    col_indices: [0, 0],
    row_ptr: [0, 2, 2],
  }
  let reordered = @core.apply_ordering(csr, [0, 1])

  assert_eq(reordered.row_ptr, [0, 1, 1])
  assert_eq(reordered.col_indices, [0])
  assert_eq(reordered.values.length(), 1)
  assert_true((reordered.values[0] - 3.0).abs() < 1.0e-12)
}

///|
test "rcm_ordering orders neighbors by degree then index" {
  let csr = @core.from_dense(
    [
      [0.0, 1.0, 1.0, 0.0, 1.0],
      [1.0, 0.0, 0.0, 1.0, 0.0],
      [1.0, 0.0, 0.0, 0.0, 0.0],
      [0.0, 1.0, 0.0, 0.0, 0.0],
      [1.0, 0.0, 0.0, 0.0, 0.0],
    ],
    0.0,
  )
  assert_eq(@core.rcm_ordering(csr), [3, 1, 4, 0, 2])
}

///|
test "rcm_ordering starts tied components at the lowest index" {
  let csr = @core.from_dense([[0.0, 0.0], [0.0, 0.0]], 0.0)
  assert_eq(@core.rcm_ordering(csr), [1, 0])
}

///|
test "rcm_ordering symmetrizes directed edges" {
  let csr = @core.from_dense(
    [[0.0, 1.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]],
    0.0,
  )
  assert_eq(@core.rcm_ordering(csr), [1, 0, 2])
}
