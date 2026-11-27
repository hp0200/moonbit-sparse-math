///|
fn diagnostics_column_count(csr : @core.SparseMatrix[Double]) -> Int32 {
  let rows = csr.row_ptr.length() - 1
  let mut max_col : Int32 = -1
  for col in csr.col_indices {
    if col > max_col {
      max_col = col
    }
  }
  if max_col < 0 {
    // CSR does not store an explicit column count. An all-zero matrix is
    // treated as square; otherwise the width is inferred from the pattern.
    rows
  } else {
    max_col + 1
  }
}

///|
fn diagnostics_value_at(
  csr : @core.SparseMatrix[Double],
  row : Int32,
  col : Int32,
) -> Double {
  let mut value = 0.0
  for k = csr.row_ptr[row]; k < csr.row_ptr[row + 1]; k = k + 1 {
    if csr.col_indices[k] == col {
      value = value + csr.values[k]
    }
  }
  value
}

///|
fn diagnostics_scale(csr : @core.SparseMatrix[Double]) -> Double {
  let mut scale = 0.0
  for value in csr.values {
    if value.is_nan() || value.is_inf() {
      return -1.0
    }
    let magnitude = value.abs()
    if magnitude > scale {
      scale = magnitude
    }
  }
  scale
}

///|
/// Checks whether a matrix is square and structurally symmetric.
///
/// Values are compared with a relative tolerance of `1e-12` based on the
/// largest stored magnitude. Explicitly stored zeros are treated as absent.
pub fn is_symmetric(csr : @core.SparseMatrix[Double]) -> Bool {
  let rows = csr.row_ptr.length() - 1
  if diagnostics_column_count(csr) != rows {
    return false
  }

  let scale = diagnostics_scale(csr)
  if scale < 0.0 {
    return false
  }
  let tolerance = scale * 1.0e-12

  for i = 0; i < rows; i = i + 1 {
    for k = csr.row_ptr[i]; k < csr.row_ptr[i + 1]; k = k + 1 {
      let j = csr.col_indices[k]
      if j < 0 || j >= rows {
        return false
      }
      let value = csr.values[k]
      if value.abs() <= tolerance {
        continue
      }
      let mirror = diagnostics_value_at(csr, j, i)
      if (value - mirror).abs() > tolerance {
        return false
      }
    }
  }
  true
}

///|
/// Checks whether a matrix is symmetric positive definite.
///
/// This implementation materializes the matrix as a dense lower-triangular
/// Cholesky factor. It is intended as a structural/numerical pre-check, not as
/// a large-scale factorization routine. Non-finite values, missing positive
/// pivots, and non-symmetric matrices are rejected.
pub fn is_positive_definite(csr : @core.SparseMatrix[Double]) -> Bool {
  if !is_symmetric(csr) {
    return false
  }

  let n = csr.row_ptr.length() - 1
  if n == 0 {
    return false
  }

  let scale = diagnostics_scale(csr)
  let tolerance = scale * 1.0e-12
  let matrix : Array[Array[Double]] = []
  for i = 0; i < n; i = i + 1 {
    matrix.push(Array::make(n, 0.0))
  }
  for i = 0; i < n; i = i + 1 {
    for k = csr.row_ptr[i]; k < csr.row_ptr[i + 1]; k = k + 1 {
      let j = csr.col_indices[k]
      matrix[i][j] = matrix[i][j] + csr.values[k]
    }
  }

  for i = 0; i < n; i = i + 1 {
    for j = 0; j <= i; j = j + 1 {
      let mut sum = matrix[i][j]
      for k = 0; k < j; k = k + 1 {
        sum = sum - matrix[i][k] * matrix[j][k]
      }
      if i == j {
        if sum.is_nan() || sum.is_inf() || sum <= tolerance {
          return false
        }
        matrix[i][j] = sum.sqrt()
      } else {
        let pivot = matrix[j][j]
        if pivot.is_nan() || pivot.is_inf() || pivot.abs() <= tolerance {
          return false
        }
        matrix[i][j] = sum / pivot
      }
    }
  }
  true
}

///|
/// Returns the connected-component ID for every row of the matrix.
///
/// The matrix pattern is interpreted as an undirected graph: every stored
/// non-zero entry `(i, j)` creates an edge in both directions. Component IDs
/// start at zero and are assigned by the smallest unvisited row index. Explicit
/// zero entries do not create graph edges.
pub fn get_connected_components(
  csr : @core.SparseMatrix[Double],
) -> Array[Int32] {
  let nodes = csr.row_ptr.length() - 1
  let adjacency : Array[Array[Int32]] = []
  for i = 0; i < nodes; i = i + 1 {
    adjacency.push([])
  }
  for i = 0; i < nodes; i = i + 1 {
    for k = csr.row_ptr[i]; k < csr.row_ptr[i + 1]; k = k + 1 {
      let j = csr.col_indices[k]
      if j < 0 || j >= nodes || csr.values[k] == 0.0 {
        continue
      }
      adjacency[i].push(j)
      if j != i {
        adjacency[j].push(i)
      }
    }
  }

  let components : Array[Int32] = Array::make(nodes, -1)
  let mut component_id = 0
  for start = 0; start < nodes; start = start + 1 {
    if components[start] != -1 {
      continue
    }
    let queue : Array[Int32] = []
    queue.push(start)
    components[start] = component_id
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      for neighbor in adjacency[node] {
        if components[neighbor] == -1 {
          components[neighbor] = component_id
          queue.push(neighbor)
        }
      }
    }
    component_id = component_id + 1
  }
  components
}
