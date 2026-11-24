fn next_random(state : Int64) -> Int64 {
  let mut x = state
  x = x ^ (x << 13)
  x = x ^ (x >> 7)
  x = x ^ (x << 17)
  x & 0x7FFF_FFFFL
}

fn generate_random_csr(
  n : Int,
  density_percent : Int64,
) -> SparseMatrix[Double] {
  let dense : Array[Array[Double]] = []
  let mut state = 88172645463325252L

  for row_index = 0; row_index < n; row_index = row_index + 1 {
    let row = Array::make(n, 0.0)
    let mut nonzeros = 0

    for col_index = 0; col_index < n; col_index = col_index + 1 {
      state = next_random(state)
      if state % 100L < density_percent {
        row[col_index] = (state % 1000L).to_int().to_double() / 1000.0 + 0.1
        nonzeros = nonzeros + 1
      }
    }

    if nonzeros == 0 {
      row[row_index] = 1.0
    }
    dense.push(row)
  }

  from_dense(dense, 0.0)
}

fn matmul_map(
  a : SparseMatrix[Double],
  b : SparseMatrix[Double],
) -> (Array[Double], Array[Int], Array[Int]) {
  let b_row_count = b.row_ptr.length() - 1
  let mut max_a_col = -1
  for col in a.col_indices {
    if col > max_a_col {
      max_a_col = col
    }
  }
  if max_a_col >= b_row_count {
    return ([], [], [0])
  }

  let result_values : Array[Double] = []
  let result_col_indices : Array[Int] = []
  let result_row_ptr : Array[Int] = [0]
  let a_row_count = a.row_ptr.length() - 1

  for a_row = 0; a_row < a_row_count; a_row = a_row + 1 {
    let products : Array[(Int, Double)] = []

    for a_pos = a.row_ptr[a_row]; a_pos < a.row_ptr[a_row + 1]; a_pos = a_pos + 1 {
      let b_row = a.col_indices[a_pos]
      let a_value = a.values[a_pos]

      for b_pos = b.row_ptr[b_row]; b_pos < b.row_ptr[b_row + 1]; b_pos = b_pos + 1 {
        products.push((
          b.col_indices[b_pos],
          a_value * b.values[b_pos],
        ))
      }
    }

    products.sort_by((left, right) => left.0.compare(right.0))

    let mut product_index = 0
    while product_index < products.length() {
      let col = products[product_index].0
      let mut sum = 0.0

      while product_index < products.length() && products[product_index].0 == col {
        sum = sum + products[product_index].1
        product_index = product_index + 1
      }

      if sum != 0.0 {
        result_values.push(sum)
        result_col_indices.push(col)
      }
    }

    result_row_ptr.push(result_values.length())
  }

  (result_values, result_col_indices, result_row_ptr)
}

fn matmul_spa(
  a : SparseMatrix[Double],
  b : SparseMatrix[Double],
) -> (Array[Double], Array[Int], Array[Int]) {
  let result = matmul(a, b).unwrap()
  let result_values = result.values
  let result_col_indices = result.col_indices
  let result_row_ptr = result.row_ptr
  (result_values, result_col_indices, result_row_ptr)
}

test "benchmark sparse matmul map vs spa" (b : @bench.T) {
  let left = generate_random_csr(1000, 1L)
  let right = generate_random_csr(1000, 1L)

  b.bench(name="matmul_map", fn() {
    b.keep(matmul_map(left, right))
  })

  b.bench(name="matmul_spa", fn() {
    b.keep(matmul_spa(left, right))
  })
}
