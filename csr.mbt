pub struct SparseMatrix {
  values : Array[Double]
  col_indices : Array[Int]
  row_ptr : Array[Int]
}

pub fn from_dense(matrix : Array[Array[Double]]) -> SparseMatrix {
  let values : Array[Double] = []
  let col_indices : Array[Int] = []
  let row_ptr = [0]
  
  for i = 0; i < matrix.length(); i = i + 1 {
    let row = matrix[i]
    for col_idx, val in row {
      if val != 0.0 {
        values.push(val)
        col_indices.push(col_idx)
      }
    }
    row_ptr.push(values.length())
  }
  
  SparseMatrix::{ values, col_indices, row_ptr }
}

pub fn to_dense(csr : SparseMatrix) -> Array[Array[Double]] {
  let rows = csr.row_ptr.length() - 1
  let mut cols = 0
  for idx in csr.col_indices {
    if idx + 1 > cols {
      cols = idx + 1
    }
  }
  
  let dense : Array[Array[Double]] = []
  for i = 0; i < rows; i = i + 1 {
    let row : Array[Double] = []
    for j = 0; j < cols; j = j + 1 {
      row.push(0.0)
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

pub fn spmv(csr : SparseMatrix, x : Array[Double]) -> Array[Double] {
  let rows = csr.row_ptr.length() - 1
  let y : Array[Double] = []
  
  for i = 0; i < rows; i = i + 1 {
    let mut sum = 0.0
    for k = csr.row_ptr[i]; k < csr.row_ptr[i + 1]; k = k + 1 {
      let col = csr.col_indices[k]
      sum = sum + csr.values[k] * x[col]
    }
    y.push(sum)
  }
  
  y
}

pub fn transpose(csr : SparseMatrix) -> SparseMatrix {
  let rows = csr.row_ptr.length() - 1
  let nnz = csr.values.length()

  // Number of columns is the largest column index plus one.
  let mut cols = 0
  for idx in csr.col_indices {
    if idx + 1 > cols {
      cols = idx + 1
    }
  }

  // Counting sort: count non-zero entries per target row (original column).
  let count = Array::make(cols + 1, 0)
  for i = 0; i < rows; i = i + 1 {
    for k = csr.row_ptr[i]; k < csr.row_ptr[i + 1]; k = k + 1 {
      let col = csr.col_indices[k]
      count[col] = count[col] + 1
    }
  }

  // Prefix sums produce the transposed row_ptr.
  let row_ptr = Array::make(cols + 1, 0)
  for j = 0; j < cols; j = j + 1 {
    row_ptr[j + 1] = row_ptr[j] + count[j]
  }

  // Fill the transposed values/col_indices using a cursor per target row.
  let values = Array::make(nnz, 0.0)
  let col_indices = Array::make(nnz, 0)
  let next = Array::makei(cols + 1, j => row_ptr[j])
  for i = 0; i < rows; i = i + 1 {
    for k = csr.row_ptr[i]; k < csr.row_ptr[i + 1]; k = k + 1 {
      let col = csr.col_indices[k]
      let pos = next[col]
      values[pos] = csr.values[k]
      col_indices[pos] = i
      next[col] = pos + 1
    }
  }

  SparseMatrix::{ values, col_indices, row_ptr }
}