///|
pub(all) struct CscMatrix[T] {
  values : Array[T]
  row_indices : Array[Int32]
  col_ptr : Array[Int32]
  rows : Int32
  cols : Int32
}

///|
pub fn[T] csr_to_csc(csr : SparseMatrix[T]) -> CscMatrix[T] {
  let rows = csr.row_ptr.length() - 1
  let mut cols = 0
  for col in csr.col_indices {
    if col + 1 > cols {
      cols = col + 1
    }
  }

  let col_values : Array[Array[T]] = []
  let col_rows : Array[Array[Int32]] = []
  for col = 0; col < cols; col = col + 1 {
    col_values.push([])
    col_rows.push([])
  }
  for row = 0; row < rows; row = row + 1 {
    for pos = csr.row_ptr[row]; pos < csr.row_ptr[row + 1]; pos = pos + 1 {
      let col = csr.col_indices[pos]
      col_values[col].push(csr.values[pos])
      col_rows[col].push(row)
    }
  }

  let values : Array[T] = []
  let row_indices : Array[Int32] = []
  let col_ptr : Array[Int32] = [0]
  for col = 0; col < cols; col = col + 1 {
    for i = 0; i < col_values[col].length(); i = i + 1 {
      values.push(col_values[col][i])
      row_indices.push(col_rows[col][i])
    }
    col_ptr.push(values.length())
  }

  CscMatrix::{ values, row_indices, col_ptr, rows, cols, }
}

///|
pub fn[T] csc_to_csr(csc : CscMatrix[T]) -> SparseMatrix[T] {
  let row_values : Array[Array[T]] = []
  let row_cols : Array[Array[Int32]] = []
  for row = 0; row < csc.rows; row = row + 1 {
    row_values.push([])
    row_cols.push([])
  }
  for col = 0; col < csc.cols; col = col + 1 {
    for pos = csc.col_ptr[col]; pos < csc.col_ptr[col + 1]; pos = pos + 1 {
      let row = csc.row_indices[pos]
      row_values[row].push(csc.values[pos])
      row_cols[row].push(col)
    }
  }

  let values : Array[T] = []
  let col_indices : Array[Int32] = []
  let row_ptr : Array[Int32] = [0]
  for row = 0; row < csc.rows; row = row + 1 {
    for i = 0; i < row_values[row].length(); i = i + 1 {
      values.push(row_values[row][i])
      col_indices.push(row_cols[row][i])
    }
    row_ptr.push(values.length())
  }

  SparseMatrix::{ values, col_indices, row_ptr, }
}

///|
pub fn[T : @luna_generic.Ring] coo_to_csc(coo : CooMatrix[T]) -> CscMatrix[T] {
  let entries : Array[(Int32, Int32, T)] = []
  for i = 0; i < coo.values.length(); i = i + 1 {
    entries.push((coo.row_indices[i], coo.col_indices[i], coo.values[i]))
  }
  entries.sort_by((left, right) => {
    if left.1 != right.1 {
      left.1.compare(right.1)
    } else {
      left.0.compare(right.0)
    }
  })

  let values : Array[T] = []
  let row_indices : Array[Int32] = []
  let col_ptr : Array[Int32] = Array::make(coo.cols + 1, 0)
  let mut entry_index = 0
  for col = 0; col < coo.cols; col = col + 1 {
    while entry_index < entries.length() && entries[entry_index].1 == col {
      let row = entries[entry_index].0
      let mut value = entries[entry_index].2
      entry_index = entry_index + 1
      while entry_index < entries.length() &&
            entries[entry_index].1 == col &&
            entries[entry_index].0 == row {
        value = value + entries[entry_index].2
        entry_index = entry_index + 1
      }
      values.push(value)
      row_indices.push(row)
    }
    col_ptr[col + 1] = values.length()
  }

  CscMatrix::{ values, row_indices, col_ptr, rows: coo.rows, cols: coo.cols, }
}

///|
pub fn[T] csc_to_coo(csc : CscMatrix[T]) -> CooMatrix[T] {
  let values : Array[T] = []
  let row_indices : Array[Int32] = []
  let col_indices : Array[Int32] = []
  for col = 0; col < csc.cols; col = col + 1 {
    for pos = csc.col_ptr[col]; pos < csc.col_ptr[col + 1]; pos = pos + 1 {
      values.push(csc.values[pos])
      row_indices.push(csc.row_indices[pos])
      col_indices.push(col)
    }
  }

  CooMatrix::{
    values,
    row_indices,
    col_indices,
    rows: csc.rows,
    cols: csc.cols,
  }
}

