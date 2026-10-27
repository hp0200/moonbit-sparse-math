test "basic sanity" {
  assert_eq(1 + 1, 2)
}

test "from_dense basic sanity" {
  let dense = [[1.0, 0.0], [0.0, 2.0]]
  let csr = from_dense(dense)
  
  assert_eq(csr.values, [1.0, 2.0])
  assert_eq(csr.col_indices, [0, 1])
  assert_eq(csr.row_ptr, [0, 1, 2])
}

test "to_dense round trip" {
  let original = [[1.0, 0.0], [0.0, 2.0]]
  let csr = from_dense(original)
  let result = to_dense(csr)
  
  assert_eq(result, original)
}

test "spmv basic" {
  let dense = [[1.0, 2.0], [0.0, 3.0]]
  let csr = from_dense(dense)
  let x = [1.0, 1.0]
  
  let y = spmv(csr, x)
  assert_eq(y, [3.0, 3.0])
}

test "diagonally dominant true" {
  let dense = [[2.0, 1.0], [1.0, 2.0]]
  let csr = from_dense(dense)
  assert_eq(is_diagonally_dominant(csr), true)
}

test "diagonally dominant false" {
  let dense = [[1.0, 2.0], [1.0, 2.0]]
  let csr = from_dense(dense)
  assert_eq(is_diagonally_dominant(csr), false)
}

test "transpose basic" {
  let a = [[1.0, 0.0], [2.0, 3.0]]
  let csr = from_dense(a)
  let t = transpose(csr)
  let result = to_dense(t)
  assert_eq(result, [[1.0, 2.0], [0.0, 3.0]])
}
test "estimate_conditioning good" {
  let dense = [[3.0, 1.0], [1.0, 3.0]]
  let csr = from_dense(dense)
  assert_eq(estimate_conditioning(csr), "Good")
}

test "estimate_conditioning ill-conditioned" {
  let dense = [[0.0, 1.0], [1.0, 0.0]]
  let csr = from_dense(dense)
  assert_eq(estimate_conditioning(csr), "Ill-conditioned (Warning)")
}

test "estimate_conditioning moderate" {
  let dense = [[1.0, 1.0], [1.0, 1.0]]
  let csr = from_dense(dense)
  assert_eq(estimate_conditioning(csr), "Moderate")
}
