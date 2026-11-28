///|
fn graph_assert_valid_csr(csr : @core.SparseMatrix[Double]) -> Unit raise {
  let rows = csr.row_ptr.length() - 1
  assert_eq(csr.row_ptr[0], 0)
  assert_eq(csr.values.length(), csr.col_indices.length())
  assert_eq(csr.row_ptr[rows], csr.values.length())
  for row = 0; row < rows; row = row + 1 {
    let start = csr.row_ptr[row]
    let end = csr.row_ptr[row + 1]
    assert_eq(start <= end, true)
    for k = start; k < end; k = k + 1 {
      assert_eq(csr.values[k], 1.0)
      if k + 1 < end {
        assert_eq(csr.col_indices[k] < csr.col_indices[k + 1], true)
      }
    }
  }
}

///|
fn graph_expect_error(
  result : Result[@core.SparseMatrix[Double], String],
) -> Unit raise {
  match result {
    Ok(_) => panic()
    Err(message) => assert_eq(message.length() > 0, true)
  }
}

///|
test "to_adjacency_list preserves directed edges without symmetrizing" {
  let csr = @core.from_dense(
    [[0.0, 1.0, 0.0], [0.0, 0.0, 1.0], [1.0, 0.0, 0.0]],
    0.0,
  )
  assert_eq(@core.to_adjacency_list(csr), [[1], [2], [0]])
}

///|
test "to_adjacency_list represents an undirected graph symmetrically" {
  let csr = @core.from_dense(
    [[0.0, 1.0, 0.0], [1.0, 0.0, 1.0], [0.0, 1.0, 0.0]],
    0.0,
  )
  let adjacency = @core.to_adjacency_list(csr)
  assert_eq(adjacency, [[1], [0, 2], [1]])
  for left = 0; left < adjacency.length(); left = left + 1 {
    for right in adjacency[left] {
      assert_eq(adjacency[right].contains(left), true)
    }
  }
}

///|
test "to_adjacency_list ignores zeros and normalizes duplicates" {
  let csr : @core.SparseMatrix[Double] = @core.SparseMatrix::{
    values: [2.0, -2.0, 0.0, 3.0, 1.0, 4.0],
    col_indices: [2, 2, 0, 1, 0, 2],
    row_ptr: [0, 4, 6],
  }
  assert_eq(@core.to_adjacency_list(csr), [[1], [0, 2]])
}

///|
test "from_adjacency_list handles empty graphs and isolated nodes" {
  let empty : Array[Array[Int32]] = []
  let empty_matrix = @core.from_adjacency_list(empty).unwrap()
  assert_eq(empty_matrix.values, [])
  assert_eq(empty_matrix.col_indices, [])
  assert_eq(empty_matrix.row_ptr, [0])
  graph_assert_valid_csr(empty_matrix)

  let isolated = @core.from_adjacency_list([[], [], []]).unwrap()
  assert_eq(isolated.values, [])
  assert_eq(isolated.col_indices, [])
  assert_eq(isolated.row_ptr, [0, 0, 0, 0])
  graph_assert_valid_csr(isolated)
}

///|
test "from_adjacency_list preserves self loops and removes duplicate edges" {
  let matrix = @core.from_adjacency_list([[0, 2, 2, 0], [], [2, 3, 2], []]).unwrap()

  assert_eq(matrix.values, [1.0, 1.0, 1.0, 1.0])
  assert_eq(matrix.col_indices, [0, 2, 2, 3])
  assert_eq(matrix.row_ptr, [0, 2, 2, 4, 4])
  graph_assert_valid_csr(matrix)
}

///|
test "from_adjacency_list round trips normalized graph structure" {
  let adjacency = [[3, 1, 1], [], [2, 0], [2, 2]]
  let matrix = @core.from_adjacency_list(adjacency).unwrap()

  assert_eq(@core.to_adjacency_list(matrix), [[1, 3], [], [0, 2], [2]])
  graph_assert_valid_csr(matrix)
}

///|
test "from_adjacency_list rejects negative and out of range columns" {
  graph_expect_error(@core.from_adjacency_list([[-1]]))
  graph_expect_error(@core.from_adjacency_list([[0, 2], [1]]))
  graph_expect_error(@core.from_adjacency_list([[0], [1], [3]]))
}

///|
test "graph conversion emits monotonic CSR row pointers and sorted columns" {
  let matrix = @core.from_adjacency_list([[4, 1, 1, 0], [], [2, 0, 2], [3], []]).unwrap()
  let rows = matrix.row_ptr.length() - 1

  assert_eq(rows, 5)
  assert_eq(matrix.row_ptr, [0, 3, 3, 5, 6, 6])
  assert_eq(matrix.col_indices, [0, 1, 4, 0, 2, 3])
  for row = 0; row < rows; row = row + 1 {
    assert_eq(matrix.row_ptr[row] <= matrix.row_ptr[row + 1], true)
    for k = matrix.row_ptr[row]; k + 1 < matrix.row_ptr[row + 1]; k = k + 1 {
      assert_eq(matrix.col_indices[k] < matrix.col_indices[k + 1], true)
      assert_eq(matrix.values[k] != 0.0, true)
    }
  }
  graph_assert_valid_csr(matrix)
}
