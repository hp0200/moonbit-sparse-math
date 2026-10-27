pub fn is_diagonally_dominant(csr : SparseMatrix) -> Bool {
  let rows = csr.row_ptr.length() - 1
  
  for i = 0; i < rows; i = i + 1 {
    let mut diag_val = 0.0
    let mut sum_off_diag = 0.0
    
    // 遍历第 i 行的所有非零元素
    for k = csr.row_ptr[i]; k < csr.row_ptr[i + 1]; k = k + 1 {
      let col = csr.col_indices[k]
      let val = csr.values[k]
      
      if col == i {
        diag_val = val
      } else {
        // 累加非对角线元素的绝对值
        sum_off_diag = sum_off_diag + val.abs()
      }
    }
    
    // 判断条件：对角线元素的绝对值 必须 严格大于 该行其他元素绝对值之和
    if diag_val.abs() <= sum_off_diag {
      return false
    }
  }
  
  true
}