///|
#derive(Eq, Debug)
pub enum SparseError {
  DimensionMismatch
}

///|
pub struct SparseMatrix[T] {
  values : Array[T]
  col_indices : Array[Int]
  row_ptr : Array[Int]
}

///|
pub fn[T : Eq] from_dense(
  matrix : Array[Array[T]],
  zero_val : T,
) -> SparseMatrix[T] {
  let values : Array[T] = []
  let col_indices : Array[Int] = []
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
  let t_values = Array::make(
    csr.values.length(),
    @luna_generic.Zero::zero(),
  )
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
