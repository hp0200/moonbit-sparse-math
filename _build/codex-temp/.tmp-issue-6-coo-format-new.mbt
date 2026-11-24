///|
pub(all) struct CooMatrix[T] {
  values : Array[T]
  row_indices : Array[Int32]
  col_indices : Array[Int32]
  rows : Int32
  cols : Int32
}

///|
pub fn[T] to_coo(csr : SparseMatrix[T]) -> CooMatrix[T] {
  let rows = csr.row_ptr.length() - 1
  let mut cols = 0
  for col in csr.col_indices {
    if col + 1 > cols {
      cols = col + 1
    }
  }

  let values : Array[T] = []
  let row_indices : Array[Int32] = []
  let col_indices : Array[Int32] = []
  for row = 0; row < rows; row = row + 1 {
    for pos = csr.row_ptr[row]; pos < csr.row_ptr[row + 1]; pos = pos + 1 {
      values.push(csr.values[pos])
      row_indices.push(row)
      col_indices.push(csr.col_indices[pos])
    }
  }

  CooMatrix::{ values, row_indices, col_indices, rows, cols, }
}

///|
pub fn[T : @luna_generic.Ring] from_coo(coo : CooMatrix[T]) -> SparseMatrix[T] {
  let entries : Array[(Int32, Int32, T)] = []
  for i = 0; i < coo.values.length(); i = i + 1 {
    entries.push((coo.row_indices[i], coo.col_indices[i], coo.values[i]))
  }
  entries.sort_by((left, right) => {
    if left.0 != right.0 {
      left.0.compare(right.0)
    } else {
      left.1.compare(right.1)
    }
  })

  let values : Array[T] = []
  let col_indices : Array[Int32] = []
  let row_ptr : Array[Int32] = Array::make(coo.rows + 1, 0)
  let mut entry_index = 0
  for row = 0; row < coo.rows; row = row + 1 {
    while entry_index < entries.length() && entries[entry_index].0 == row {
      let col = entries[entry_index].1
      let mut value = entries[entry_index].2
      entry_index = entry_index + 1
      while entry_index < entries.length() &&
            entries[entry_index].0 == row &&
            entries[entry_index].1 == col {
        value = value + entries[entry_index].2
        entry_index = entry_index + 1
      }
      values.push(value)
      col_indices.push(col)
    }
    row_ptr[row + 1] = values.length()
  }

  SparseMatrix::{ values, col_indices, row_ptr, }
}

