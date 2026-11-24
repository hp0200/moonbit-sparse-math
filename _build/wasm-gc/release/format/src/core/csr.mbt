///|
#derive(Eq, Debug)
pub(all) enum SparseError {
  DimensionMismatch
}

///|
pub(all) struct SparseMatrix[T] {
  values : Array[T]
  col_indices : Array[Int32]
  row_ptr : Array[Int32]
}

///|
pub fn[T : Eq] from_dense(
  matrix : Array[Array[T]],
  zero_val : T,
) -> SparseMatrix[T] {
  let values : Array[T] = []
  let col_indices : Array[Int32] = []
  let row_ptr = [0]

  for i = 0; i < matrix.length(); i = i + 1 {
    let row = matrix[i]
    for col_idx, val in row {
      if val != zero_val {
        values.push(val)
        col_indices.push(col_idx)
      }
    }
    row_ptr.push(values.length())
  }

  SparseMatrix::{ values, col_indices, row_ptr, }
}

///|
pub fn[T] to_dense(csr : SparseMatrix[T], zero_val : T) -> Array[Array[T]] {
  let rows = csr.row_ptr.length() - 1
  let mut cols = 0
  for idx in csr.col_indices {
    if idx + 1 > cols {
      cols = idx + 1
    }
  }

  let dense : Array[Array[T]] = []
  for i = 0; i < rows; i = i + 1 {
    let row : Array[T] = []
    for j = 0; j < cols; j = j + 1 {
      row.push(zero_val)
    }
    dense.push(row)
  }

  for i = 0; i < rows; i = i + 1 {
    for k = csr.row_ptr[i]; k < csr.row_ptr[i + 1]; k = k + 1 {
      let col = csr.col_indices[k]
      dense[i][col] = csr.values[k]
    }
  }

  dense
}

///|
pub fn[T : @luna_generic.Ring] spmv(
  csr : SparseMatrix[T],
  x : Array[T],
) -> Result[Array[T], SparseError] {
  let rows = csr.row_ptr.length() - 1
  if x.length() != rows {
    return Err(DimensionMismatch)
  }

  let y : Array[T] = []
  for i = 0; i < rows; i = i + 1 {
    let mut sum = @luna_generic.Zero::zero()
    for k = csr.row_ptr[i]; k < csr.row_ptr[i + 1]; k = k + 1 {
      let col = csr.col_indices[k]
      sum = sum + csr.values[k] * x[col]
    }
    y.push(sum)
  }

  Ok(y)
}

///|
pub fn spmv_simd(
  csr : SparseMatrix[Double],
  x : Array[Double],
) -> Array[Double] {
  let rows = csr.row_ptr.length() - 1
  if x.length() != rows {
    return []
  }

  let y : Array[Double] = []
  let zero = @v128.f64x2_const(0.0, 0.0)
  for i = 0; i < rows; i = i + 1 {
    let start = csr.row_ptr[i]
    let end = csr.row_ptr[i + 1]
    let mut acc0 = zero
    let mut acc1 = zero
    let mut k = start

    while k + 3 < end {
      let values0 = @v128.f64x2_const(csr.values[k], csr.values[k + 1])
      let values1 = @v128.f64x2_const(csr.values[k + 2], csr.values[k + 3])
      let x0 = @v128.f64x2_const(
        x[csr.col_indices[k]],
        x[csr.col_indices[k + 1]],
      )
      let x1 = @v128.f64x2_const(
        x[csr.col_indices[k + 2]],
        x[csr.col_indices[k + 3]],
      )
      acc0 = @v128.f64x2_add(acc0, @v128.f64x2_mul(values0, x0))
      acc1 = @v128.f64x2_add(acc1, @v128.f64x2_mul(values1, x1))
      k = k + 4
    }

    let mut sum = @v128.f64x2_extract_lane(acc0, 0) +
      @v128.f64x2_extract_lane(acc0, 1) +
      @v128.f64x2_extract_lane(acc1, 0) +
      @v128.f64x2_extract_lane(acc1, 1)
    while k < end {
      sum = sum + csr.values[k] * x[csr.col_indices[k]]
      k = k + 1
    }
    y.push(sum)
  }

  y
}

///|
pub fn[T : @luna_generic.Ring] transpose(
  csr : SparseMatrix[T],
) -> SparseMatrix[T] {
  let rows = csr.row_ptr.length() - 1
  let mut cols = 0
  for idx in csr.col_indices {
    if idx + 1 > cols {
      cols = idx + 1
    }
  }

  let counts = Array::make(cols, 0)
  for i = 0; i < csr.values.length(); i = i + 1 {
    counts[csr.col_indices[i]] = counts[csr.col_indices[i]] + 1
  }

  let t_row_ptr = Array::make(cols + 1, 0)
  for j = 0; j < cols; j = j + 1 {
    t_row_ptr[j + 1] = t_row_ptr[j] + counts[j]
  }

  let next = Array::make(cols, 0)
  let t_values = Array::make(csr.values.length(), @luna_generic.Zero::zero())
  let t_col_indices = Array::make(csr.values.length(), 0)

  for i = 0; i < rows; i = i + 1 {
    for k = csr.row_ptr[i]; k < csr.row_ptr[i + 1]; k = k + 1 {
      let col = csr.col_indices[k]
      let pos = t_row_ptr[col] + next[col]
      t_values[pos] = csr.values[k]
      t_col_indices[pos] = i
      next[col] = next[col] + 1
    }
  }

  SparseMatrix::{
    values: t_values,
    col_indices: t_col_indices,
    row_ptr: t_row_ptr,
  }
}
