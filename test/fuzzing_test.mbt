///|
fn fuzz_seed_next(seed : Int32) -> Int32 {
  (seed * 1103 + 12345) % 32768
}

///|
fn fuzz_random_value(seed : Int32) -> Double {
  (seed % 5 - 2).to_double()
}

///|
fn pad_columns(
  matrix : Array[Array[Double]],
  columns : Int32,
) -> Array[Array[Double]] {
  let padded : Array[Array[Double]] = []
  for row in matrix {
    let padded_row = Array::make(columns, 0.0)
    for j = 0; j < row.length(); j = j + 1 {
      padded_row[j] = row[j]
    }
    padded.push(padded_row)
  }
  padded
}

///|
test "fuzzing sparse matmul against brute force" {
  let mut seed = 20261105
  for case_index = 0; case_index < 50; case_index = case_index + 1 {
    seed = fuzz_seed_next(seed)
    let a_rows = seed % 4 + 1
    seed = fuzz_seed_next(seed)
    let shared = seed % 4 + 1
    seed = fuzz_seed_next(seed)
    let b_cols = seed % 4 + 1

    let dense_a : Array[Array[Double]] = []
    for i = 0; i < a_rows; i = i + 1 {
      let row = Array::make(shared, 0.0)
      for j = 0; j < shared; j = j + 1 {
        seed = fuzz_seed_next(seed)
        row[j] = fuzz_random_value(seed)
      }
      dense_a.push(row)
    }

    let dense_b : Array[Array[Double]] = []
    for i = 0; i < shared; i = i + 1 {
      let row = Array::make(b_cols, 0.0)
      for j = 0; j < b_cols; j = j + 1 {
        seed = fuzz_seed_next(seed)
        row[j] = fuzz_random_value(seed)
      }
      dense_b.push(row)
    }

    let expected : Array[Array[Double]] = []
    for i = 0; i < a_rows; i = i + 1 {
      let row = Array::make(b_cols, 0.0)
      for j = 0; j < b_cols; j = j + 1 {
        let mut sum = 0.0
        for k = 0; k < shared; k = k + 1 {
          sum = sum + dense_a[i][k] * dense_b[k][j]
        }
        row[j] = sum
      }
      expected.push(row)
    }

    let actual = @core.to_dense(
      @ops.matmul(
        @core.from_dense(dense_a, 0.0),
        @core.from_dense(dense_b, 0.0),
      ).unwrap(),
      0.0,
    )
    assert_eq(pad_columns(actual, b_cols), expected)
  }
}
