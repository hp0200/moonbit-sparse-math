///|
pub(all) struct Property {
  name : String
  check : (@core.SparseMatrix[Double]) -> Result[Unit, String]
}

///|
fn property_rows(matrix : @core.SparseMatrix[Double]) -> Int32 {
  matrix.row_ptr.length() - 1
}

///|
fn property_cols(matrix : @core.SparseMatrix[Double]) -> Int32 {
  let rows = property_rows(matrix)
  let mut max_col = -1
  for col in matrix.col_indices {
    if col > max_col {
      max_col = col
    }
  }
  if max_col < 0 {
    rows
  } else {
    max_col + 1
  }
}

///|
fn property_shape(matrix : @core.SparseMatrix[Double]) -> String {
  "\{property_rows(matrix)}x\{property_cols(matrix)}"
}

///|
fn property_close(
  expected : Double,
  actual : Double,
  relative_tolerance : Double,
  absolute_tolerance : Double,
) -> Bool {
  let magnitude = if expected.abs() > actual.abs() {
    expected.abs()
  } else {
    actual.abs()
  }
  (expected - actual).abs() <=
  absolute_tolerance + relative_tolerance * magnitude
}

///|
fn property_tolerance(
  expected : Double,
  actual : Double,
  relative_tolerance : Double,
  absolute_tolerance : Double,
) -> Double {
  let magnitude = if expected.abs() > actual.abs() {
    expected.abs()
  } else {
    actual.abs()
  }
  absolute_tolerance + relative_tolerance * magnitude
}

///|
fn property_value_at(
  matrix : @core.SparseMatrix[Double],
  row : Int32,
  col : Int32,
) -> Double {
  let mut value = 0.0
  for pos = matrix.row_ptr[row]; pos < matrix.row_ptr[row + 1]; pos = pos + 1 {
    if matrix.col_indices[pos] == col {
      value = value + matrix.values[pos]
    }
  }
  value
}

///|
fn property_compare_sparse_to_dense(
  property_name : String,
  matrix : @core.SparseMatrix[Double],
  expected : Array[Array[Double]],
  rows : Int32,
  cols : Int32,
  relative_tolerance : Double,
  absolute_tolerance : Double,
) -> Result[Unit, String] {
  if matrix.row_ptr.length() != rows + 1 {
    return Err(
      "\{property_name}: matrix \{property_shape(matrix)}, expected \{rows}x\{cols}, row_ptr length \{matrix.row_ptr.length()}, expected \{rows + 1}",
    )
  }
  for row = 0; row < rows; row = row + 1 {
    if matrix.row_ptr[row] > matrix.row_ptr[row + 1] {
      return Err(
        "\{property_name}: matrix \{property_shape(matrix)}, row \{row}: row_ptr is not monotonic",
      )
    }
  }
  for pos = 0; pos < matrix.col_indices.length(); pos = pos + 1 {
    if matrix.col_indices[pos] < 0 || matrix.col_indices[pos] >= cols {
      return Err(
        "\{property_name}: matrix \{property_shape(matrix)}, stored position \{pos}: column index \{matrix.col_indices[pos]} is outside 0..\{cols - 1}",
      )
    }
  }
  for row = 0; row < rows; row = row + 1 {
    for col = 0; col < cols; col = col + 1 {
      let expected_value = expected[row][col]
      let actual_value = property_value_at(matrix, row, col)
      if !property_close(
          expected_value, actual_value, relative_tolerance, absolute_tolerance,
        ) {
        let tolerance = property_tolerance(
          expected_value, actual_value, relative_tolerance, absolute_tolerance,
        )
        return Err(
          "\{property_name}: matrix \{rows}x\{cols}, position (\{row}, \{col}): expected \{expected_value}, actual \{actual_value}, abs_diff \{(expected_value - actual_value).abs()}, tolerance \{tolerance}",
        )
      }
    }
  }
  Ok(())
}

///|
fn property_compare_csr(
  property_name : String,
  actual : @core.SparseMatrix[Double],
  expected : @core.SparseMatrix[Double],
) -> Result[Unit, String] {
  if actual.row_ptr.length() != expected.row_ptr.length() {
    return Err(
      "\{property_name}: row_ptr length expected \{expected.row_ptr.length()}, actual \{actual.row_ptr.length()}",
    )
  }
  for row = 0; row < expected.row_ptr.length(); row = row + 1 {
    if actual.row_ptr[row] != expected.row_ptr[row] {
      return Err(
        "\{property_name}: row_ptr[\{row}] expected \{expected.row_ptr[row]}, actual \{actual.row_ptr[row]}",
      )
    }
  }
  if actual.col_indices.length() != expected.col_indices.length() {
    return Err(
      "\{property_name}: stored entry count expected \{expected.col_indices.length()}, actual \{actual.col_indices.length()}",
    )
  }
  if actual.values.length() != expected.values.length() {
    return Err(
      "\{property_name}: value count expected \{expected.values.length()}, actual \{actual.values.length()}",
    )
  }
  for pos = 0; pos < expected.col_indices.length(); pos = pos + 1 {
    if actual.col_indices[pos] != expected.col_indices[pos] {
      return Err(
        "\{property_name}: col_indices[\{pos}] expected \{expected.col_indices[pos]}, actual \{actual.col_indices[pos]}",
      )
    }
    let expected_value = expected.values[pos]
    let actual_value = actual.values[pos]
    if !property_close(expected_value, actual_value, 1.0e-12, 1.0e-14) {
      let tolerance = property_tolerance(
        expected_value, actual_value, 1.0e-12, 1.0e-14,
      )
      return Err(
        "\{property_name}: values[\{pos}] expected \{expected_value}, actual \{actual_value}, abs_diff \{(expected_value - actual_value).abs()}, tolerance \{tolerance}",
      )
    }
  }
  Ok(())
}

///|
fn property_dense_snapshot(
  matrix : @core.SparseMatrix[Double],
) -> Array[Array[Double]] {
  let rows = property_rows(matrix)
  let cols = property_cols(matrix)
  let dense : Array[Array[Double]] = []
  for row = 0; row < rows; row = row + 1 {
    let values = Array::make(cols, 0.0)
    for pos = matrix.row_ptr[row]; pos < matrix.row_ptr[row + 1]; pos = pos + 1 {
      let col = matrix.col_indices[pos]
      values[col] = values[col] + matrix.values[pos]
    }
    dense.push(values)
  }
  dense
}

///|
fn property_identity(n : Int32) -> @core.SparseMatrix[Double] {
  let dense : Array[Array[Double]] = []
  for row = 0; row < n; row = row + 1 {
    let values = Array::make(n, 0.0)
    values[row] = 1.0
    dense.push(values)
  }
  @core.from_dense(dense, 0.0)
}

///|
fn property_explicit_zero_probe() -> @core.SparseMatrix[Double] {
  let coo = @core.CooMatrix::{
    values: [2.0, 0.0, 3.0],
    row_indices: [0, 0, 1],
    col_indices: [0, 1, 1],
    rows: 2,
    cols: 2,
  }
  @core.from_coo(coo)
}

///|
pub fn spmv_linearity(
  matrix : @core.SparseMatrix[Double],
) -> Result[Unit, String] {
  let rows = property_rows(matrix)
  let x = Array::make(rows, 0.0)
  let y = Array::make(rows, 0.0)
  for i = 0; i < rows; i = i + 1 {
    x[i] = (i % 5).to_double() * 0.25 - 0.5
    y[i] = (i % 7).to_double() * -0.2 + 0.3
  }
  let alpha = 0.75
  let beta = -1.25
  let combined = Array::make(rows, 0.0)
  for i = 0; i < rows; i = i + 1 {
    combined[i] = alpha * x[i] + beta * y[i]
  }
  let ax = match @core.spmv(matrix, x) {
    Ok(values) => values
    Err(_) =>
      return Err(
        "spmv_linearity: matrix \{property_shape(matrix)}: spmv rejected a dimensionally valid vector",
      )
  }
  let ay = match @core.spmv(matrix, y) {
    Ok(values) => values
    Err(_) =>
      return Err(
        "spmv_linearity: matrix \{property_shape(matrix)}: spmv rejected a dimensionally valid vector",
      )
  }
  let lhs = match @core.spmv(matrix, combined) {
    Ok(values) => values
    Err(_) =>
      return Err(
        "spmv_linearity: matrix \{property_shape(matrix)}: spmv rejected a dimensionally valid vector",
      )
  }
  for i = 0; i < rows; i = i + 1 {
    let expected = alpha * ax[i] + beta * ay[i]
    let actual = lhs[i]
    if !property_close(expected, actual, 1.0e-10, 1.0e-12) {
      let tolerance = property_tolerance(expected, actual, 1.0e-10, 1.0e-12)
      return Err(
        "spmv_linearity: matrix \{property_shape(matrix)}, row \{i}: expected \{expected}, actual \{actual}, abs_diff \{(expected - actual).abs()}, tolerance \{tolerance}",
      )
    }
  }
  Ok(())
}

///|
pub fn spmv_zero_vector(
  matrix : @core.SparseMatrix[Double],
) -> Result[Unit, String] {
  let rows = property_rows(matrix)
  let zeros = Array::make(rows, 0.0)
  let result = match @core.spmv(matrix, zeros) {
    Ok(values) => values
    Err(_) =>
      return Err(
        "spmv_zero_vector: matrix \{property_shape(matrix)}: spmv rejected a dimensionally valid vector",
      )
  }
  for i = 0; i < result.length(); i = i + 1 {
    if !property_close(0.0, result[i], 1.0e-12, 1.0e-14) {
      return Err(
        "spmv_zero_vector: matrix \{property_shape(matrix)}, row \{i}: expected 0.0, actual \{result[i]}",
      )
    }
  }
  Ok(())
}

///|
pub fn spgemm_dense_equivalence(
  matrix : @core.SparseMatrix[Double],
) -> Result[Unit, String] {
  let rows = property_rows(matrix)
  let cols = property_cols(matrix)
  let right = @core.transpose(matrix)
  let product = match @ops.matmul(matrix, right) {
    Ok(value) => value
    Err(_) =>
      return Err(
        "spgemm_dense_equivalence: matrix \{rows}x\{cols}: sparse multiplication rejected compatible operands",
      )
  }
  let expected : Array[Array[Double]] = []
  for row = 0; row < rows; row = row + 1 {
    let values = Array::make(rows, 0.0)
    for col = 0; col < rows; col = col + 1 {
      let mut sum = 0.0
      for k = 0; k < cols; k = k + 1 {
        sum = sum +
          property_value_at(matrix, row, k) * property_value_at(matrix, col, k)
      }
      values[col] = sum
    }
    expected.push(values)
  }
  property_compare_sparse_to_dense(
    "spgemm_dense_equivalence", product, expected, rows, rows, 1.0e-9, 1.0e-11,
  )
}

///|
pub fn spgemm_identity(
  matrix : @core.SparseMatrix[Double],
) -> Result[Unit, String] {
  let rows = property_rows(matrix)
  let cols = property_cols(matrix)
  let left_identity = property_identity(rows)
  let right_identity = property_identity(cols)
  let left_product = match @ops.matmul(left_identity, matrix) {
    Ok(value) => value
    Err(_) =>
      return Err(
        "spgemm_identity: matrix \{rows}x\{cols}: I * A rejected compatible operands",
      )
  }
  let right_product = match @ops.matmul(matrix, right_identity) {
    Ok(value) => value
    Err(_) =>
      return Err(
        "spgemm_identity: matrix \{rows}x\{cols}: A * I rejected compatible operands",
      )
  }
  let expected = property_dense_snapshot(matrix)
  match
    property_compare_sparse_to_dense(
      "spgemm_identity(I*A)", left_product, expected, rows, cols, 1.0e-10, 1.0e-12,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  property_compare_sparse_to_dense(
    "spgemm_identity(A*I)", right_product, expected, rows, cols, 1.0e-10, 1.0e-12,
  )
}

///|
pub fn transpose_involution(
  matrix : @core.SparseMatrix[Double],
) -> Result[Unit, String] {
  let double_transpose = @core.transpose(@core.transpose(matrix))
  property_compare_sparse_to_dense(
    "transpose_involution",
    double_transpose,
    property_dense_snapshot(matrix),
    property_rows(matrix),
    property_cols(matrix),
    1.0e-12,
    1.0e-14,
  )
}

///|
pub fn format_roundtrip_coo(
  matrix : @core.SparseMatrix[Double],
) -> Result[Unit, String] {
  let roundtrip = @core.from_coo(@core.to_coo(matrix))
  match property_compare_csr("format_roundtrip_coo", roundtrip, matrix) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let probe = property_explicit_zero_probe()
  let probe_roundtrip = @core.from_coo(@core.to_coo(probe))
  property_compare_csr(
    "format_roundtrip_coo(explicit-zero)", probe_roundtrip, probe,
  )
}

///|
pub fn format_roundtrip_csc(
  matrix : @core.SparseMatrix[Double],
) -> Result[Unit, String] {
  let roundtrip = @core.csc_to_csr(@core.csr_to_csc(matrix))
  match property_compare_csr("format_roundtrip_csc", roundtrip, matrix) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let probe = property_explicit_zero_probe()
  let probe_roundtrip = @core.csc_to_csr(@core.csr_to_csc(probe))
  property_compare_csr(
    "format_roundtrip_csc(explicit-zero)", probe_roundtrip, probe,
  )
}

///|
fn property_independently_symmetric(
  matrix : @core.SparseMatrix[Double],
) -> Bool {
  let rows = property_rows(matrix)
  let cols = property_cols(matrix)
  if rows != cols {
    return false
  }
  let mut scale = 0.0
  for value in matrix.values {
    if value.is_nan() || value.is_inf() {
      return false
    }
    if value.abs() > scale {
      scale = value.abs()
    }
  }
  let tolerance = scale * 1.0e-12
  for row = 0; row < rows; row = row + 1 {
    for col = 0; col < cols; col = col + 1 {
      let left = property_value_at(matrix, row, col)
      let right = property_value_at(matrix, col, row)
      if (left - right).abs() > tolerance {
        return false
      }
    }
  }
  true
}

///|
pub fn symmetry_consistency(
  matrix : @core.SparseMatrix[Double],
) -> Result[Unit, String] {
  let expected = property_independently_symmetric(matrix)
  let actual = @algebra.is_symmetric(matrix)
  if actual != expected {
    return Err(
      "symmetry_consistency: matrix \{property_shape(matrix)}: expected is_symmetric to return \{expected}, actual \{actual}",
    )
  }
  if actual {
    let rows = property_rows(matrix)
    let cols = property_cols(matrix)
    let scale = if rows == 0 {
      1.0
    } else {
      let mut maximum = 0.0
      for value in matrix.values {
        if value.abs() > maximum {
          maximum = value.abs()
        }
      }
      if maximum > 0.0 {
        maximum
      } else {
        1.0
      }
    }
    let tolerance = 1.0e-12 * scale
    for row = 0; row < rows; row = row + 1 {
      for col = 0; col < cols; col = col + 1 {
        let left = property_value_at(matrix, row, col)
        let right = property_value_at(matrix, col, row)
        if (left - right).abs() > tolerance {
          return Err(
            "symmetry_consistency: matrix \{property_shape(matrix)}, position (\{row}, \{col}): expected symmetric value \{right}, actual \{left}, abs_diff \{(left - right).abs()}, tolerance \{tolerance}",
          )
        }
      }
    }
  }
  Ok(())
}

///|
fn property_independent_diagonal_dominance(
  matrix : @core.SparseMatrix[Double],
) -> Bool {
  let rows = property_rows(matrix)
  for row = 0; row < rows; row = row + 1 {
    let mut diagonal = 0.0
    let mut off_diagonal = 0.0
    for pos = matrix.row_ptr[row]; pos < matrix.row_ptr[row + 1]; pos = pos + 1 {
      if matrix.col_indices[pos] == row {
        diagonal = diagonal + matrix.values[pos]
      } else {
        off_diagonal = off_diagonal + matrix.values[pos].abs()
      }
    }
    if diagonal.abs() <= off_diagonal {
      return false
    }
  }
  true
}

///|
pub fn diagonal_dominance_check(
  matrix : @core.SparseMatrix[Double],
) -> Result[Unit, String] {
  let expected = property_independent_diagonal_dominance(matrix)
  let actual = @algebra.is_diagonally_dominant(matrix)
  if actual != expected {
    return Err(
      "diagonal_dominance_check: matrix \{property_shape(matrix)}: expected strict diagonal dominance to be \{expected}, actual \{actual}",
    )
  }
  Ok(())
}

///|
pub fn spadd_subtract(
  matrix : @core.SparseMatrix[Double],
) -> Result[Unit, String] {
  let offset = @ops.scale(matrix, 0.375)
  let sum = match @ops.add(matrix, offset) {
    Ok(value) => value
    Err(message) =>
      return Err(
        "spadd_subtract: matrix \{property_shape(matrix)}: A + B failed: \{message}",
      )
  }
  let rounded = match @ops.add(sum, @ops.scale(offset, -1.0)) {
    Ok(value) => value
    Err(message) =>
      return Err(
        "spadd_subtract: matrix \{property_shape(matrix)}: (A + B) - B failed: \{message}",
      )
  }
  property_compare_sparse_to_dense(
    "spadd_subtract",
    rounded,
    property_dense_snapshot(matrix),
    property_rows(matrix),
    property_cols(matrix),
    1.0e-10,
    1.0e-12,
  )
}

///|
pub fn all_properties() -> Array[Property] {
  [
    Property::{ name: "spmv_linearity", check: spmv_linearity, },
    Property::{ name: "spmv_zero_vector", check: spmv_zero_vector, },
    Property::{
      name: "spgemm_dense_equivalence",
      check: spgemm_dense_equivalence,
    },
    Property::{ name: "spgemm_identity", check: spgemm_identity, },
    Property::{ name: "transpose_involution", check: transpose_involution, },
    Property::{ name: "format_roundtrip_coo", check: format_roundtrip_coo, },
    Property::{ name: "format_roundtrip_csc", check: format_roundtrip_csc, },
    Property::{ name: "symmetry_consistency", check: symmetry_consistency, },
    Property::{
      name: "diagonal_dominance_check",
      check: diagonal_dominance_check,
    },
    Property::{ name: "spadd_subtract", check: spadd_subtract, },
  ]
}
