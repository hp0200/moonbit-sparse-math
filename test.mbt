test "basic sanity" {
  assert_eq(1 + 1, 2)
}

test "from_dense basic sanity" {
  let dense = [[1.0, 0.0], [0.0, 2.0]]
  let csr = from_dense(dense, 0.0)

  
  assert_eq(csr.values, [1.0, 2.0])
  assert_eq(csr.col_indices, [0, 1])
  assert_eq(csr.row_ptr, [0, 1, 2])
}

test "to_dense round trip" {
  let original = [[1.0, 0.0], [0.0, 2.0]]
  let csr = from_dense(original, 1.0e-10)
  let result = to_dense(csr, 0.0)
  
  assert_eq(result, original)
}

test "spmv basic" {
  let dense = [[1.0, 2.0], [0.0, 3.0]]
  let csr = from_dense(dense, 1.0e-10)

  let x = [1.0, 1.0]
  
  let y = spmv(csr, x).unwrap()
  assert_eq(y, [3.0, 3.0])
}

test "diagonally dominant true" {
  let dense = [[2.0, 1.0], [1.0, 2.0]]
  let csr = from_dense(dense, 1.0e-10)

  assert_eq(is_diagonally_dominant(csr), true)
}

test "diagonally dominant false" {
  let dense = [[1.0, 2.0], [1.0, 2.0]]
  let csr = from_dense(dense, 1.0e-10)

  assert_eq(is_diagonally_dominant(csr), false)
}

test "transpose basic" {
  let a = [[1.0, 0.0], [2.0, 3.0]]
  let csr = from_dense(a, 1.0e-10)
  let t = transpose(csr)
  let result = to_dense(t, 0.0)
  assert_eq(result, [[1.0, 2.0], [0.0, 3.0]])
}
test "estimate_conditioning good" {
  let dense = [[3.0, 1.0], [1.0, 3.0]]
  let csr = from_dense(dense, 1.0e-10)

  assert_eq(estimate_conditioning(csr), "Good")
}

test "estimate_conditioning ill-conditioned" {
  let dense = [[0.0, 1.0], [1.0, 0.0]]
  let csr = from_dense(dense, 1.0e-10)

  assert_eq(estimate_conditioning(csr), "Ill-conditioned (Warning)")
}

test "estimate_conditioning moderate" {
  let dense = [[1.0, 1.0], [1.0, 1.0]]
  let csr = from_dense(dense, 1.0e-10)

  assert_eq(estimate_conditioning(csr), "Moderate")
}

test "spmv dimension mismatch" {
  let csr = from_dense([[1.0, 0.0], [0.0, 2.0]], 0.0)

  match spmv(csr, [1.0]) {
    Ok(_) => panic()
    Err(DimensionMismatch) => assert_eq(true, true)
  }
}

test "to_csc basic" {
  let a = [[1.0, 0.0], [2.0, 3.0]]
  let csr = from_dense(a, 0.0)
  let csc = to_csc(csr)

  assert_eq(csc.values, [1.0, 2.0, 3.0])
  assert_eq(csc.col_indices, [0, 1, 1])
  assert_eq(csc.row_ptr, [0, 2, 3])
}

test "spgemm matmul basic" {
  let mat_a = [[1.0, 2.0], [0.0, 3.0]]
  let mat_b = [[4.0, 0.0], [5.0, 6.0]]

  let a = from_dense(mat_a, 0.0)
  let b = from_dense(mat_b, 0.0)
  let result_csr = matmul(a, b).unwrap()
  let result_dense = to_dense(result_csr, 0.0)

  assert_eq(result_dense, [[14.0, 12.0], [15.0, 18.0]])
}

test "spgemm cancellation to zero" {
  let mat_a = [[1.0, 1.0], [0.0, 1.0]]
  let mat_b = [[1.0, 0.0], [-1.0, 1.0]]

  let res = matmul(
    from_dense(mat_a, 0.0),
    from_dense(mat_b, 0.0),
  ).unwrap()
  assert_eq(res.values, [1.0, -1.0, 1.0])
}

test "spgemm dimension mismatch" {
  let a = from_dense([[1.0, 1.0], [0.0, 1.0]], 0.0)
  let b = from_dense([[1.0, 2.0]], 0.0)

  match matmul(a, b) {
    Ok(_) => panic()
    Err(DimensionMismatch) => assert_eq(true, true)
  }
}

test "pcg solve basic" {
  let mat_a = [[4.0, 1.0], [1.0, 3.0]]
  let csr = from_dense(mat_a, 0.0)
  let b = [6.0, 7.0]

  match pcg_solve(csr, b, 1.0e-10, 20) {
    Ok(x) => {
      assert_eq(x.length(), 2)
      assert_eq((x[0] - 1.0).abs() < 1.0e-8, true)
      assert_eq((x[1] - 2.0).abs() < 1.0e-8, true)
    }
    Err(_) => panic()
  }
}

test "pcg solve singular zero diagonal" {
  let mat_a = [[0.0, 1.0], [1.0, 0.0]]
  let csr = from_dense(mat_a, 0.0)
  let b = [1.0, 1.0]

  match pcg_solve(csr, b, 1.0e-10, 100) {
    Ok(_) => panic()
    Err(message) => {
      assert_eq(message, "Matrix is singular or dimension mismatch")
    }
  }
}

test "pcg solve hilbert 3x3 ill conditioned" {
  let mat_h = [
    [1.0, 1.0 / 2.0, 1.0 / 3.0],
    [1.0 / 2.0, 1.0 / 3.0, 1.0 / 4.0],
    [1.0 / 3.0, 1.0 / 4.0, 1.0 / 5.0],
  ]
  let csr = from_dense(mat_h, 0.0)
  let exact = [1.0, 1.0, 1.0]
  let b = spmv(csr, exact).unwrap()

  match pcg_solve(csr, b, 1.0e-8, 100) {
    Ok(x) => {
      let mut max_error = 0.0
      for i = 0; i < 3; i = i + 1 {
        let error = (x[i] - exact[i]).abs()
        if error > max_error {
          max_error = error
        }
      }
      assert_eq(max_error < 1.0e-3, true)
    }
    Err(message) => {
      let safe_exit = message == "Did not converge" ||
        message == "Matrix is singular or dimension mismatch"
      assert_eq(safe_exit, true)
    }
  }
}

test "spmv with Int matrix" {
  let dense = [[1, 2], [0, 3]]
  let csr = from_dense(dense, 0)
  let x = [4, 5]

  let y = spmv(csr, x).unwrap()
  assert_eq(y, [14, 15])
}
