///|
pub fn[T : @luna_generic.Ring] to_csc(
  csr : SparseMatrix[T],
) -> SparseMatrix[T] {
  let rows = csr.row_ptr.length() - 1
  let mut cols = 0
  // 找最大列索引，确定列数
  for c in csr.col_indices {
    if c + 1 > cols {
      cols = c + 1
    }
  }

  // 统计每列非零元个数
  let counts = Array::make(cols, 0)
  for i = 0; i < csr.values.length(); i = i + 1 {
    let col = csr.col_indices[i]
    counts[col] = counts[col] + 1
  }

  // 计算每列的偏移量（即新的 row_ptr）
  let csc_row_ptr = Array::make(cols + 1, 0)
  for j = 0; j < cols; j = j + 1 {
    csc_row_ptr[j + 1] = csc_row_ptr[j] + counts[j]
  }

  let next = Array::make(cols, 0)
  let csc_values = Array::make(
    csr.values.length(),
    @luna_generic.Zero::zero(),
  )
  let csc_row_indices = Array::make(csr.values.length(), 0)

  // 遍历原矩阵，把行号和值填入对应位置
  for i = 0; i < rows; i = i + 1 {
    for k = csr.row_ptr[i]; k < csr.row_ptr[i + 1]; k = k + 1 {
      let col = csr.col_indices[k]
      let pos = csc_row_ptr[col] + next[col]
      csc_values[pos] = csr.values[k]
      csc_row_indices[pos] = i
      next[col] = next[col] + 1
    }
  }

  SparseMatrix::{
    values: csc_values,
    col_indices: csc_row_indices,
    row_ptr: csc_row_ptr,
  }
}
