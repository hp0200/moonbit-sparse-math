# moonbit-sparse-math


```mbt check
test "demo" {
  let dense_data = [
    [4.0, 1.0, 0.0],
    [1.0, 3.0, 1.0],
    [0.0, 1.0, 2.0]
  ]
  let csr = from_dense(dense_data)
  let is_safe = is_diagonally_dominant(csr)
  let inflow = [10.0, 20.0, 30.0]
  let prediction = spmv(csr, inflow)
  assert_eq(is_safe, true)
  assert_eq(prediction, [60.0, 100.0, 80.0])
}```
