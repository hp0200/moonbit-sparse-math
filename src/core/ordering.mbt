///|
fn ordering_empty_matrix() -> SparseMatrix[Double] {
  SparseMatrix::{ values: [], col_indices: [], row_ptr: [0], }
}

///|
fn ordering_adjacency(csr : SparseMatrix[Double]) -> Array[Array[Int32]] {
  let nodes = csr.row_ptr.length() - 1
  let adjacency : Array[Array[Int32]] = []
  for i = 0; i < nodes; i = i + 1 {
    adjacency.push([])
  }
  for i = 0; i < nodes; i = i + 1 {
    for k = csr.row_ptr[i]; k < csr.row_ptr[i + 1]; k = k + 1 {
      let j = csr.col_indices[k]
      if j < 0 || j >= nodes || j == i || csr.values[k] == 0.0 {
        continue
      }
      if !adjacency[i].contains(j) {
        adjacency[i].push(j)
      }
      if !adjacency[j].contains(i) {
        adjacency[j].push(i)
      }
    }
  }
  adjacency
}

///|
/// Computes a Reverse Cuthill-McKee ordering of the matrix graph.
///
/// The sparse pattern is interpreted as an undirected graph. Each connected
/// component starts at its minimum-degree unvisited node, and every BFS
/// frontier is expanded in ascending neighbor-degree order. The returned array
/// uses the convention `perm[new_index] = old_index`.
pub fn rcm_ordering(csr : SparseMatrix[Double]) -> Array[Int32] {
  let nodes = csr.row_ptr.length() - 1
  if nodes == 0 {
    return []
  }

  let adjacency = ordering_adjacency(csr)
  let visited = Array::make(nodes, false)
  let cm_order : Array[Int32] = []

  while cm_order.length() < nodes {
    let mut start = -1
    let mut start_degree = 0
    for i = 0; i < nodes; i = i + 1 {
      if !visited[i] {
        let degree = adjacency[i].length()
        if start < 0 || degree < start_degree {
          start = i
          start_degree = degree
        }
      }
    }
    if start < 0 {
      break
    }

    visited[start] = true
    cm_order.push(start)
    let queue : Array[Int32] = [start]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      let candidates : Array[Int32] = []
      for neighbor in adjacency[node] {
        if !visited[neighbor] {
          candidates.push(neighbor)
        }
      }
      candidates.sort_by((left, right) => {
        let left_degree = adjacency[left].length()
        let right_degree = adjacency[right].length()
        if left_degree != right_degree {
          left_degree.compare(right_degree)
        } else {
          left.compare(right)
        }
      })
      for neighbor in candidates {
        if !visited[neighbor] {
          visited[neighbor] = true
          cm_order.push(neighbor)
          queue.push(neighbor)
        }
      }
    }
  }

  let ordering : Array[Int32] = []
  for i = cm_order.length() - 1; i >= 0; i = i - 1 {
    ordering.push(cm_order[i])
  }
  ordering
}

///|
/// Applies a node permutation to a square CSR matrix.
///
/// `perm[new_index] = old_index`, and the result satisfies
/// `new_matrix[i, j] = old_matrix[perm[i], perm[j]]`. Duplicate output columns
/// are merged, explicit zeros are omitted, and each row is sorted by column.
/// An invalid permutation or a rectangular/invalid CSR returns an empty matrix.
pub fn apply_ordering(
  csr : SparseMatrix[Double],
  perm : Array[Int32],
) -> SparseMatrix[Double] {
  let nodes = csr.row_ptr.length() - 1
  if perm.length() != nodes {
    return ordering_empty_matrix()
  }
  if nodes == 0 {
    return ordering_empty_matrix()
  }

  let seen = Array::make(nodes, false)
  for node in perm {
    if node < 0 || node >= nodes || seen[node] {
      return ordering_empty_matrix()
    }
    seen[node] = true
  }
  for col in csr.col_indices {
    if col < 0 || col >= nodes {
      return ordering_empty_matrix()
    }
  }

  let inverse = Array::make(nodes, 0)
  for new_index = 0; new_index < nodes; new_index = new_index + 1 {
    inverse[perm[new_index]] = new_index
  }

  let values : Array[Double] = []
  let col_indices : Array[Int32] = []
  let row_ptr : Array[Int32] = Array::make(nodes + 1, 0)
  for new_row = 0; new_row < nodes; new_row = new_row + 1 {
    let old_row = perm[new_row]
    let entries : Array[(Int32, Double)] = []
    for k = csr.row_ptr[old_row]; k < csr.row_ptr[old_row + 1]; k = k + 1 {
      let old_col = csr.col_indices[k]
      entries.push((inverse[old_col], csr.values[k]))
    }
    entries.sort_by((left, right) => left.0.compare(right.0))

    let mut entry_index = 0
    while entry_index < entries.length() {
      let new_col = entries[entry_index].0
      let mut value = entries[entry_index].1
      entry_index = entry_index + 1
      while entry_index < entries.length() && entries[entry_index].0 == new_col {
        value = value + entries[entry_index].1
        entry_index = entry_index + 1
      }
      if value != 0.0 {
        values.push(value)
        col_indices.push(new_col)
      }
    }
    row_ptr[new_row + 1] = values.length()
  }

  SparseMatrix::{ values, col_indices, row_ptr, }
}
