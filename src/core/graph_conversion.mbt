///|
fn graph_conversion_normalized_columns(
  csr : SparseMatrix[Double],
  row : Int32,
) -> Array[Int32] {
  let entries : Array[(Int32, Double)] = []
  for k = csr.row_ptr[row]; k < csr.row_ptr[row + 1]; k = k + 1 {
    let col = csr.col_indices[k]
    if col >= 0 {
      entries.push((col, csr.values[k]))
    }
  }
  entries.sort_by((left, right) => left.0.compare(right.0))

  let columns : Array[Int32] = []
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
      columns.push(col)
    }
  }
  columns
}

///|
/// Converts a CSR matrix into a directed adjacency list.
///
/// Each row contains the destination node indices for its stored non-zero
/// entries. Duplicate columns are merged, exact zero values are omitted, and
/// the resulting destination lists are sorted and unique.
pub fn to_adjacency_list(csr : SparseMatrix[Double]) -> Array[Array[Int32]] {
  if csr.row_ptr.length() == 0 {
    return []
  }

  let rows = csr.row_ptr.length() - 1
  let adjacency : Array[Array[Int32]] = []
  for row = 0; row < rows; row = row + 1 {
    adjacency.push(graph_conversion_normalized_columns(csr, row))
  }
  adjacency
}

///|
/// Builds a square CSR matrix from a directed adjacency list.
///
/// Every listed edge receives weight `1.0`. Self-loops are preserved, duplicate
/// destinations are removed, and empty rows represent isolated nodes. Every
/// source or destination must be a valid node in `0..<adj.length()`; otherwise
/// the function returns `Err` without constructing a partial matrix.
pub fn from_adjacency_list(
  adjacency : Array[Array[Int32]],
) -> Result[SparseMatrix[Double], String] {
  let nodes = adjacency.length()
  for row = 0; row < nodes; row = row + 1 {
    for col in adjacency[row] {
      if col < 0 || col >= nodes {
        return Err(
          "adjacency list contains invalid edge \{row} -> \{col} for \{nodes} nodes",
        )
      }
    }
  }

  let values : Array[Double] = []
  let col_indices : Array[Int32] = []
  let row_ptr : Array[Int32] = Array::make(nodes + 1, 0)
  for row = 0; row < nodes; row = row + 1 {
    let sorted : Array[Int32] = []
    for col in adjacency[row] {
      sorted.push(col)
    }
    sorted.sort_by((left, right) => left.compare(right))

    let mut previous = -1
    for col in sorted {
      if col != previous {
        values.push(1.0)
        col_indices.push(col)
        previous = col
      }
    }
    row_ptr[row + 1] = values.length()
  }

  Ok(SparseMatrix::{ values, col_indices, row_ptr, })
}
