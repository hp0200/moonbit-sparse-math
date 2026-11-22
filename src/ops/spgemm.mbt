///|
pub fn[T : @luna_generic.Ring + Eq] matmul(
  a : @core.SparseMatrix[T],
  b : @core.SparseMatrix[T],
) -> Result[@core.SparseMatrix[T], @core.SparseError] {
  let b_row_count = b.row_ptr.length() - 1
  let mut max_b_col = -1
  for i = 0; i < b.col_indices.length(); i = i + 1 {
    if b.col_indices[i] > max_b_col {
      max_b_col = b.col_indices[i]
    }
  }
  let b_col_count = max_b_col + 1

  let mut max_a_col = -1
  for col in a.col_indices {
    if col > max_a_col {
      max_a_col = col
    }
  }
  if max_a_col >= b_row_count {
    return Err(@core.DimensionMismatch)
  }

  let result_values : Array[T] = []
  let result_col_indices : Array[Int32] = []
  let result_row_ptr : Array[Int32] = [0]

  let acc : Array[T] = Array::make(b_col_count, @luna_generic.Zero::zero())
  let touched : Array[Bool] = Array::make(b_col_count, false)

  let a_row_count = a.row_ptr.length() - 1
  for a_row = 0; a_row < a_row_count; a_row = a_row + 1 {
    let a_start = a.row_ptr[a_row]
    let a_end = a.row_ptr[a_row + 1]

    for a_pos = a_start; a_pos < a_end; a_pos = a_pos + 1 {
      let b_row = a.col_indices[a_pos]
      let a_value = a.values[a_pos]
      let b_start = b.row_ptr[b_row]
      let b_end = b.row_ptr[b_row + 1]

      for b_pos = b_start; b_pos < b_end; b_pos = b_pos + 1 {
        let b_col = b.col_indices[b_pos]
        touched[b_col] = true
        acc[b_col] = acc[b_col] + a_value * b.values[b_pos]
      }
    }

    for b_col = 0; b_col < b_col_count; b_col = b_col + 1 {
      if touched[b_col] {
        let value = acc[b_col]
        if value != @luna_generic.Zero::zero() {
          result_values.push(value)
          result_col_indices.push(b_col)
        }
        acc[b_col] = @luna_generic.Zero::zero()
        touched[b_col] = false
      }
    }

    result_row_ptr.push(result_values.length())
  }

  Ok(@core.SparseMatrix::{
    values: result_values,
    col_indices: result_col_indices,
    row_ptr: result_row_ptr,
  })
}
