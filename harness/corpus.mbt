///|
pub(all) struct CorpusCase {
  name : String
  matrix : @core.SparseMatrix[Double]
}

///|
fn corpus_seed_state(seed : Int32) -> Array[Int64] {
  let normalized = if seed == 0 { 1 } else { seed }
  [normalized.to_int64() ^ 0x5DEECE66DL]
}

///|
fn corpus_next_random(state : Array[Int64]) -> Int64 {
  let mut value = state[0]
  value = value ^ (value << 13)
  value = value ^ (value >> 7)
  value = value ^ (value << 17)
  value = value & 0x7FFF_FFFFL
  state[0] = value
  value
}

///|
fn corpus_random_unit(state : Array[Int64]) -> Double {
  let value = corpus_next_random(state)
  (value % 1_000_000L).to_int().to_double() / 1_000_000.0
}

///|
/// Generates a seeded sparse matrix. The last stored coordinate is always
/// populated because CSR does not retain an explicit column count.
pub fn random_sparse(
  rows : Int32,
  cols : Int32,
  density : Double,
  seed : Int32,
) -> @core.SparseMatrix[Double] {
  if rows <= 0 || cols <= 0 {
    return @core.from_dense([], 0.0)
  }
  let state = corpus_seed_state(seed)
  let dense : Array[Array[Double]] = []
  for row = 0; row < rows; row = row + 1 {
    let values = Array::make(cols, 0.0)
    for col = 0; col < cols; col = col + 1 {
      let roll = corpus_random_unit(state)
      if roll < density {
        values[col] = 0.25 + corpus_random_unit(state) * 1.75
      }
    }
    dense.push(values)
  }
  dense[rows - 1][cols - 1] = 0.5 + corpus_random_unit(state)
  @core.from_dense(dense, 0.0)
}

///|
/// Generates a symmetrically banded, strictly row diagonally dominant matrix.
pub fn diagonal_dominant(n : Int32, seed : Int32) -> @core.SparseMatrix[Double] {
  if n <= 0 {
    return @core.from_dense([], 0.0)
  }
  let state = corpus_seed_state(seed)
  let dense : Array[Array[Double]] = []
  for row = 0; row < n; row = row + 1 {
    dense.push(Array::make(n, 0.0))
  }
  for row = 0; row < n; row = row + 1 {
    if row > 0 {
      let value = 0.25 + corpus_random_unit(state)
      dense[row][row - 1] = value
      dense[row - 1][row] = value
    }
    if row + 1 < n {
      let value = 0.25 + corpus_random_unit(state)
      dense[row][row + 1] = value
      dense[row + 1][row] = value
    }
  }
  for row = 0; row < n; row = row + 1 {
    let mut off_diagonal = 0.0
    for col = 0; col < n; col = col + 1 {
      if row != col {
        off_diagonal = off_diagonal + dense[row][col].abs()
      }
    }
    dense[row][row] = off_diagonal + 1.0 + corpus_random_unit(state) * 3.0
  }
  @core.from_dense(dense, 0.0)
}

///|
/// Constructs `A = L * L^T + n * I` from a seeded lower-triangular factor.
pub fn symmetric_positive_definite(
  n : Int32,
  seed : Int32,
) -> @core.SparseMatrix[Double] {
  if n <= 0 {
    return @core.from_dense([], 0.0)
  }
  let state = corpus_seed_state(seed)
  let factor : Array[Array[Double]] = []
  for row = 0; row < n; row = row + 1 {
    factor.push(Array::make(n, 0.0))
  }
  for row = 0; row < n; row = row + 1 {
    factor[row][row] = 1.0 + corpus_random_unit(state)
    for col = 0; col < row; col = col + 1 {
      if col + 2 >= row {
        factor[row][col] = corpus_random_unit(state) * 1.5 - 0.75
      }
    }
  }

  let dense : Array[Array[Double]] = []
  for row = 0; row < n; row = row + 1 {
    let values = Array::make(n, 0.0)
    for col = 0; col < n; col = col + 1 {
      let mut sum = 0.0
      let limit = if row < col { row } else { col }
      for k = 0; k <= limit; k = k + 1 {
        sum = sum + factor[row][k] * factor[col][k]
      }
      if row == col {
        sum = sum + n.to_double()
      }
      values[col] = sum
    }
    dense.push(values)
  }
  @core.from_dense(dense, 0.0)
}

///|
/// Builds a block-diagonal matrix with the requested number of components.
pub fn block_diagonal(
  blocks : Int32,
  seed : Int32,
) -> @core.SparseMatrix[Double] {
  if blocks <= 0 {
    return @core.from_dense([], 0.0)
  }
  let state = corpus_seed_state(seed)
  let block_sizes : Array[Int32] = []
  let mut total_size = 0
  for block = 0; block < blocks; block = block + 1 {
    let size = 2 + block % 2
    block_sizes.push(size)
    total_size = total_size + size
  }
  let dense : Array[Array[Double]] = []
  for row = 0; row < total_size; row = row + 1 {
    dense.push(Array::make(total_size, 0.0))
  }
  let mut offset = 0
  for block = 0; block < blocks; block = block + 1 {
    let size = block_sizes[block]
    for local_row = 0; local_row < size; local_row = local_row + 1 {
      let row = offset + local_row
      dense[row][row] = 3.0 + corpus_random_unit(state)
      if local_row + 1 < size {
        let value = 0.5 + corpus_random_unit(state) * 0.5
        dense[row][row + 1] = value
        dense[row + 1][row] = value
      }
    }
    offset = offset + size
  }
  @core.from_dense(dense, 0.0)
}

///|
/// Creates a symmetric banded matrix with `bandwidth` sub/super-diagonals.
pub fn banded(
  n : Int32,
  bandwidth : Int32,
  seed : Int32,
) -> @core.SparseMatrix[Double] {
  if n <= 0 {
    return @core.from_dense([], 0.0)
  }
  let state = corpus_seed_state(seed)
  let effective_bandwidth = if bandwidth < 0 {
    0
  } else if bandwidth >= n {
    n - 1
  } else {
    bandwidth
  }
  let dense : Array[Array[Double]] = []
  for row = 0; row < n; row = row + 1 {
    let values = Array::make(n, 0.0)
    for col = 0; col < n; col = col + 1 {
      let distance = if row > col { row - col } else { col - row }
      if distance == 0 {
        values[col] = 4.0 + corpus_random_unit(state)
      } else if distance <= effective_bandwidth {
        values[col] = corpus_random_unit(state) * 1.5 - 0.75
      }
    }
    dense.push(values)
  }
  if n > 0 {
    dense[n - 1][n - 1] = 4.0 + corpus_random_unit(state)
  }
  @core.from_dense(dense, 0.0)
}

///|
/// Builds a Hilbert matrix, a classic ill-conditioned test matrix.
pub fn ill_conditioned(n : Int32) -> @core.SparseMatrix[Double] {
  if n <= 0 {
    return @core.from_dense([], 0.0)
  }
  let dense : Array[Array[Double]] = []
  for row = 0; row < n; row = row + 1 {
    let values = Array::make(n, 0.0)
    for col = 0; col < n; col = col + 1 {
      values[col] = 1.0 / (row + col + 1).to_double()
    }
    dense.push(values)
  }
  @core.from_dense(dense, 0.0)
}

///|
/// Returns the deterministic corpus used by the property runner.
pub fn corpus(scale : String, seed : Int32) -> Array[CorpusCase] {
  let values : Array[CorpusCase] = []
  if scale == "small" {
    values.push(CorpusCase::{
      name: "random_sparse",
      matrix: random_sparse(7, 7, 0.18, seed),
    })
    values.push(CorpusCase::{
      name: "diagonal_dominant",
      matrix: diagonal_dominant(7, seed + 1),
    })
    values.push(CorpusCase::{
      name: "symmetric_positive_definite",
      matrix: symmetric_positive_definite(7, seed + 2),
    })
    values.push(CorpusCase::{
      name: "block_diagonal",
      matrix: block_diagonal(3, seed + 3),
    })
    values.push(CorpusCase::{ name: "banded", matrix: banded(7, 2, seed + 4), })
    values.push(CorpusCase::{
      name: "ill_conditioned",
      matrix: ill_conditioned(5),
    })
  } else if scale == "medium" {
    values.push(CorpusCase::{
      name: "random_sparse",
      matrix: random_sparse(18, 18, 0.08, seed),
    })
    values.push(CorpusCase::{
      name: "diagonal_dominant",
      matrix: diagonal_dominant(18, seed + 1),
    })
    values.push(CorpusCase::{
      name: "symmetric_positive_definite",
      matrix: symmetric_positive_definite(18, seed + 2),
    })
    values.push(CorpusCase::{
      name: "block_diagonal",
      matrix: block_diagonal(5, seed + 3),
    })
    values.push(CorpusCase::{ name: "banded", matrix: banded(18, 3, seed + 4), })
    values.push(CorpusCase::{
      name: "ill_conditioned",
      matrix: ill_conditioned(9),
    })
  }
  values
}
