///|
fn basic_ops_row_count(a : @core.SparseMatrix[Double]) -> Int32 {
  a.row_ptr.length() - 1
}

///|
fn basic_ops_col_count(a : @core.SparseMatrix[Double]) -> Int32 {
  let rows = basic_ops_row_count(a)
  let mut max_col = -1
  for col in a.col_indices {
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
fn basic_ops_empty_rows(rows : Int32) -> @core.SparseMatrix[Double] {
  @core.SparseMatrix::{
    values: [],
    col_indices: [],
    row_ptr: Array::make(rows + 1, 0),
  }
}

///|
fn basic_ops_normalized_row(
  a : @core.SparseMatrix[Double],
  row : Int32,
) -> Array[(Int32, Double)] {
  let entries : Array[(Int32, Double)] = []
  for k = a.row_ptr[row]; k < a.row_ptr[row + 1]; k = k + 1 {
    entries.push((a.col_indices[k], a.values[k]))
  }
  entries.sort_by((left, right) => left.0.compare(right.0))

  let normalized : Array[(Int32, Double)] = []
  let mut entry_index = 0
  while entry_index < entries.length() {
    let col = entries[entry_index].0
    let mut value = entries[entry_index].1
    entry_index = entry_index + 1
    while entry_index < entries.length() && entries[entry_index].0 == col {
      value = value + entries[entry_index].1
      entry_index = entry_index + 1
    }
    if value != 0.0 {
      normalized.push((col, value))
    }
  }
  normalized
}

///|
/// Adds two CSR matrices with identical dimensions.
///
/// Matching coordinates are summed, duplicate entries are merged, and exact
/// zeros are omitted from the result.
pub fn add(
  a : @core.SparseMatrix[Double],
  b : @core.SparseMatrix[Double],
) -> Result[@core.SparseMatrix[Double], String] {
  let rows = basic_ops_row_count(a)
  if rows != basic_ops_row_count(b) ||
    basic_ops_col_count(a) != basic_ops_col_count(b) {
    return Err("Matrix dimensions do not match for addition")
  }

  let values : Array[Double] = []
  let col_indices : Array[Int32] = []
  let row_ptr : Array[Int32] = Array::make(rows + 1, 0)
  for row = 0; row < rows; row = row + 1 {
    let left = basic_ops_normalized_row(a, row)
    let right = basic_ops_normalized_row(b, row)
    let mut left_index = 0
    let mut right_index = 0
    while left_index < left.length() || right_index < right.length() {
      if left_index >= left.length() {
        let entry = right[right_index]
        values.push(entry.1)
        col_indices.push(entry.0)
        right_index = right_index + 1
      } else if right_index >= right.length() {
        let entry = left[left_index]
        values.push(entry.1)
        col_indices.push(entry.0)
        left_index = left_index + 1
      } else if left[left_index].0 == right[right_index].0 {
        let value = left[left_index].1 + right[right_index].1
        if value != 0.0 {
          values.push(value)
          col_indices.push(left[left_index].0)
        }
        left_index = left_index + 1
        right_index = right_index + 1
      } else if left[left_index].0 < right[right_index].0 {
        let entry = left[left_index]
        values.push(entry.1)
        col_indices.push(entry.0)
        left_index = left_index + 1
      } else {
        let entry = right[right_index]
        values.push(entry.1)
        col_indices.push(entry.0)
        right_index = right_index + 1
      }
    }
    row_ptr[row + 1] = values.length()
  }

  Ok(@core.SparseMatrix::{ values, col_indices, row_ptr, })
}

///|
/// Multiplies every stored value by `alpha`.
///
/// A zero scalar produces a zero-row structure with the same number of rows;
/// exact zero results are omitted.
pub fn scale(
  a : @core.SparseMatrix[Double],
  alpha : Double,
) -> @core.SparseMatrix[Double] {
  let rows = basic_ops_row_count(a)
  if alpha == 0.0 {
    return basic_ops_empty_rows(rows)
  }

  let values : Array[Double] = []
  let col_indices : Array[Int32] = []
  let row_ptr : Array[Int32] = Array::make(rows + 1, 0)
  for row = 0; row < rows; row = row + 1 {
    for entry in basic_ops_normalized_row(a, row) {
      let value = entry.1 * alpha
      if value != 0.0 {
        values.push(value)
        col_indices.push(entry.0)
      }
    }
    row_ptr[row + 1] = values.length()
  }
  @core.SparseMatrix::{ values, col_indices, row_ptr, }
}

///|
/// Computes the Hadamard product of two CSR matrices with identical dimensions.
///
/// Only coordinates present in both matrices can contribute; exact zero
/// products are omitted.
pub fn elementwise_mul(
  a : @core.SparseMatrix[Double],
  b : @core.SparseMatrix[Double],
) -> Result[@core.SparseMatrix[Double], String] {
  let rows = basic_ops_row_count(a)
  if rows != basic_ops_row_count(b) ||
    basic_ops_col_count(a) != basic_ops_col_count(b) {
    return Err("Matrix dimensions do not match for elementwise multiplication")
  }

  let values : Array[Double] = []
  let col_indices : Array[Int32] = []
  let row_ptr : Array[Int32] = Array::make(rows + 1, 0)
  for row = 0; row < rows; row = row + 1 {
    let left = basic_ops_normalized_row(a, row)
    let right = basic_ops_normalized_row(b, row)
    let mut left_index = 0
    let mut right_index = 0
    while left_index < left.length() && right_index < right.length() {
      if left[left_index].0 == right[right_index].0 {
        let value = left[left_index].1 * right[right_index].1
        if value != 0.0 {
          values.push(value)
          col_indices.push(left[left_index].0)
        }
        left_index = left_index + 1
        right_index = right_index + 1
      } else if left[left_index].0 < right[right_index].0 {
        left_index = left_index + 1
      } else {
        right_index = right_index + 1
      }
    }
    row_ptr[row + 1] = values.length()
  }

  Ok(@core.SparseMatrix::{ values, col_indices, row_ptr, })
}

///|
/// Computes `A * diag(d)` by scaling column `j` by `d[j]`.
///
/// The diagonal length must equal the inferred matrix column count.
pub fn diag_scale(
  a : @core.SparseMatrix[Double],
  d : Array[Double],
) -> Result[@core.SparseMatrix[Double], String] {
  let rows = basic_ops_row_count(a)
  if d.length() != basic_ops_col_count(a) {
    return Err("Diagonal length does not match matrix column count")
  }

  let values : Array[Double] = []
  let col_indices : Array[Int32] = []
  let row_ptr : Array[Int32] = Array::make(rows + 1, 0)
  for row = 0; row < rows; row = row + 1 {
    for entry in basic_ops_normalized_row(a, row) {
      let value = entry.1 * d[entry.0]
      if value != 0.0 {
        values.push(value)
        col_indices.push(entry.0)
      }
    }
    row_ptr[row + 1] = values.length()
  }
  Ok(@core.SparseMatrix::{ values, col_indices, row_ptr, })
}

///|
/// Extracts rows in the half-open interval `[start, end)`.
///
/// Invalid intervals return `Err`; output rows are normalized and contain no
/// explicit zeros.
pub fn get_row_slice(
  a : @core.SparseMatrix[Double],
  start : Int32,
  end : Int32,
) -> Result[@core.SparseMatrix[Double], String] {
  let rows = basic_ops_row_count(a)
  if start < 0 || end > rows || start > end {
    return Err("Row slice is out of bounds")
  }

  let values : Array[Double] = []
  let col_indices : Array[Int32] = []
  let row_ptr : Array[Int32] = [0]
  for row = start; row < end; row = row + 1 {
    for entry in basic_ops_normalized_row(a, row) {
      values.push(entry.1)
      col_indices.push(entry.0)
    }
    row_ptr.push(values.length())
  }
  Ok(@core.SparseMatrix::{ values, col_indices, row_ptr, })
}
