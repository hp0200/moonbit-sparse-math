///|
const NEBULA_NODE_COUNT : Int = 5000

///|
const NEBULA_STEP_COUNT : Int = 60

///|
extern "wasm" fn store_i32(address : Int32, value : Int32) =
  #|(func (param i32 i32) (i32.store (local.get 0) (local.get 1)))

///|
fn build_nebula_graph(node_count : Int) -> @core.SparseMatrix[Double] {
  let values : Array[Double] = []
  let col_indices : Array[Int32] = []
  let row_ptr : Array[Int32] = [0]

  for row = 0; row < node_count; row = row + 1 {
    let has_third_edge = row % 2 == 0

    col_indices.push((row + 1) % node_count)
    values.push(if has_third_edge { 0.45 } else { 0.60 })

    col_indices.push((row + 2) % node_count)
    values.push(if has_third_edge { 0.35 } else { 0.40 })

    if has_third_edge {
      col_indices.push((row + 3) % node_count)
      values.push(0.20)
    }

    row_ptr.push(values.length())
  }

  @core.SparseMatrix::{ values, col_indices, row_ptr }
}

///|
/// Runs a 60-step energy pulse simulation over a 5000-node sparse network.
///
/// Returns `(linear_memory_ptr, f64_element_count)` for a row-major matrix of
/// 60 frames x 5000 nodes. The caller can create a Float64Array view directly
/// over the WASM memory.
pub fn run_nebula_demo() -> (Int, Int) {
  let matrix = build_nebula_graph(NEBULA_NODE_COUNT)
  let element_count = NEBULA_STEP_COUNT * NEBULA_NODE_COUNT
  let start_address = allocate_linear_bytes(element_count * 8)
  if start_address < 0 {
    abort("Failed to allocate Wasm linear memory for nebula demo")
  }

  let mut pulse : Array[Double] = Array::make(NEBULA_NODE_COUNT, 0.0)
  for i = 0; i < 12; i = i + 1 {
    let node = (i * 397 + 23) % NEBULA_NODE_COUNT
    pulse[node] = 1.0 + (i % 3).to_double() * 0.35
  }

  let mut offset = 0
  for _step = 0; _step < NEBULA_STEP_COUNT; _step = _step + 1 {
    for node = 0; node < NEBULA_NODE_COUNT; node = node + 1 {
      store_f64(start_address + offset, pulse[node])
      offset = offset + 8
    }
    pulse = @core.spmv_simd(matrix, pulse)
  }

  (start_address, element_count)
}

///|
pub fn nebula_result_ptr(result : (Int, Int)) -> Int {
  let (ptr, _) = result
  ptr
}

///|
pub fn nebula_result_count(result : (Int, Int)) -> Int {
  let (_, count) = result
  count
}

///|
pub fn nebula_node_count() -> Int {
  NEBULA_NODE_COUNT
}

///|
pub fn nebula_step_count() -> Int {
  NEBULA_STEP_COUNT
}

///|
const DYN_GENERATION : Int = 0

///|
const DYN_ROWS : Int = 1

///|
const DYN_ITERATIONS : Int = 2

///|
const DYN_NNZ : Int = 3

///|
const DYN_ROW_PTR_ADDR : Int = 4

///|
const DYN_COL_INDICES_ADDR : Int = 5

///|
const DYN_ARENA_BASE : Int = 6

///|
const DYN_ARENA_CAPACITY : Int = 7

///|
let dynamic_state : Array[Int] = [0, 0, 0, 0, 0, 0, 0, 0]

///|
fn clamp_int(value : Int, minimum : Int, maximum : Int) -> Int {
  if value < minimum {
    minimum
  } else if value > maximum {
    maximum
  } else {
    value
  }
}

///|
fn align_to_8(value : Int) -> Int {
  ((value + 7) / 8) * 8
}

///|
fn ensure_dynamic_arena(required_bytes : Int) -> Int {
  let rounded_bytes = ((required_bytes + 65535) / 65536) * 65536
  if dynamic_state[DYN_ARENA_BASE] != 0 &&
    required_bytes <= dynamic_state[DYN_ARENA_CAPACITY] {
    return dynamic_state[DYN_ARENA_BASE]
  }
  let base = allocate_linear_bytes(rounded_bytes)
  if base < 0 {
    abort("Failed to allocate dynamic graph linear memory")
  }
  dynamic_state[DYN_ARENA_BASE] = base
  dynamic_state[DYN_ARENA_CAPACITY] = rounded_bytes
  base
}

///|
fn build_dynamic_offsets(
  nodes_count : Int,
  degree : Int,
  generation : Int,
) -> Array[Int] {
  let offsets : Array[Int] = []
  let seen : Array[Bool] = Array::make(nodes_count, false)
  offsets.push(0)
  seen[0] = true

  let pair_count = (degree - 1) / 2
  let local_pair_target = (pair_count * 2) / 3
  let mut distance = 1
  while distance < nodes_count && offsets.length() < 1 + local_pair_target * 2 {
    if !seen[distance] {
      seen[distance] = true
      offsets.push(distance)
    }
    let mirror = nodes_count - distance
    if offsets.length() < degree && mirror != 0 && !seen[mirror] {
      seen[mirror] = true
      offsets.push(mirror)
    }
    distance = distance + 1
  }

  let max_jump = if nodes_count / 2 < 1 { 1 } else { nodes_count / 2 }
  let mut scan = 0
  while offsets.length() < degree && scan < nodes_count * 4 {
    let jump = 1 +
      ((scan * 7919 + generation * 104729 + pair_count * 31337) % max_jump)
    if !seen[jump] {
      seen[jump] = true
      offsets.push(jump)
    }
    let mirror = nodes_count - jump
    if offsets.length() < degree && mirror != 0 && !seen[mirror] {
      seen[mirror] = true
      offsets.push(mirror)
    }
    scan = scan + 1
  }

  let mut fallback = 1
  while offsets.length() < degree && fallback < nodes_count {
    if !seen[fallback] {
      seen[fallback] = true
      offsets.push(fallback)
    }
    let mirror = nodes_count - fallback
    if offsets.length() < degree && mirror != 0 && !seen[mirror] {
      seen[mirror] = true
      offsets.push(mirror)
    }
    fallback = fallback + 1
  }

  offsets
}

///|
fn build_dynamic_graph(
  nodes_count : Int,
  sparsity_factor : Int,
  generation : Int,
) -> (@core.SparseMatrix[Double], Int) {
  let average_degree = (nodes_count * sparsity_factor) / 1000
  let mut degree = if average_degree < 3 { 3 } else { average_degree }
  if degree % 2 == 0 {
    degree = degree + 1
  }
  let max_degree = if nodes_count % 2 == 0 { nodes_count - 1 } else {
    nodes_count - 2
  }
  if degree > max_degree {
    degree = max_degree
  }

  let offsets = build_dynamic_offsets(nodes_count, degree, generation)
  let weight = 1.0 / degree.to_double()
  let values : Array[Double] = []
  let col_indices : Array[Int32] = []
  let row_ptr : Array[Int32] = Array::make(nodes_count + 1, 0)

  for row = 0; row < nodes_count; row = row + 1 {
    for offset in offsets {
      let mut column = row + offset
      if column >= nodes_count {
        column = column - nodes_count
      }
      col_indices.push(column)
      values.push(weight)
    }
    row_ptr[row + 1] = values.length()
  }

  (@core.SparseMatrix::{ values, col_indices, row_ptr }, degree)
}

///|
/// Generates a dynamic sparse graph and runs SIMD SpMV for the requested
/// number of propagation steps.
///
/// `sparsity_factor` is measured in tenths of a percent: 1 = 0.1%, 50 = 5.0%.
/// Returns `(energy_ptr, energy_element_count)` for an iteration-major matrix
/// of doubles. The CSR structure and graph metadata are exposed through the
/// `dynamic_*` accessors below.
pub fn compute_dynamic_graph(
  nodes_count : Int,
  sparsity_factor : Int,
  iterations : Int,
) -> (Int, Int) {
  let nodes = clamp_int(nodes_count, 8, 20000)
  let sparsity = clamp_int(sparsity_factor, 1, 50)
  let step_count = clamp_int(iterations, 1, 240)
  dynamic_state[DYN_GENERATION] = dynamic_state[DYN_GENERATION] + 1

  let (matrix, _degree) = build_dynamic_graph(
    nodes,
    sparsity,
    dynamic_state[DYN_GENERATION],
  )
  let nnz = matrix.values.length()
  let element_count = nodes * step_count
  let frames : Array[Double] = Array::make(element_count, 0.0)

  let mut pulse : Array[Double] = Array::make(nodes, 0.0)
  let seed_count = if nodes < 16 { nodes } else { 12 }
  for i = 0; i < seed_count; i = i + 1 {
    let node = (i * 619 + dynamic_state[DYN_GENERATION] * 131) % nodes
    pulse[node] = 1.0 + (i % 4).to_double() * 0.25
  }

  let mut frame_index = 0
  for _step = 0; _step < step_count; _step = _step + 1 {
    for node = 0; node < nodes; node = node + 1 {
      frames[frame_index] = pulse[node]
      frame_index = frame_index + 1
    }
    pulse = @core.spmv_simd(matrix, pulse)
  }

  let energy_bytes = element_count * 8
  let row_ptr_bytes = (nodes + 1) * 4
  let col_indices_bytes = nnz * 4
  let required = align_to_8(energy_bytes) +
    align_to_8(row_ptr_bytes) + align_to_8(col_indices_bytes)
  let base = ensure_dynamic_arena(required)
  let energy_addr = base
  let row_ptr_addr = energy_addr + align_to_8(energy_bytes)
  let col_indices_addr = row_ptr_addr + align_to_8(row_ptr_bytes)

  for i = 0; i < element_count; i = i + 1 {
    store_f64(energy_addr + i * 8, frames[i])
  }
  for i = 0; i < matrix.row_ptr.length(); i = i + 1 {
    store_i32(row_ptr_addr + i * 4, matrix.row_ptr[i])
  }
  for i = 0; i < nnz; i = i + 1 {
    store_i32(col_indices_addr + i * 4, matrix.col_indices[i])
  }

  dynamic_state[DYN_ROWS] = nodes
  dynamic_state[DYN_ITERATIONS] = step_count
  dynamic_state[DYN_NNZ] = nnz
  dynamic_state[DYN_ROW_PTR_ADDR] = row_ptr_addr
  dynamic_state[DYN_COL_INDICES_ADDR] = col_indices_addr

  (energy_addr, element_count)
}

///|
pub fn dynamic_result_ptr(result : (Int, Int)) -> Int {
  let (ptr, _) = result
  ptr
}

///|
pub fn dynamic_result_count(result : (Int, Int)) -> Int {
  let (_, count) = result
  count
}

///|
pub fn dynamic_graph_rows() -> Int {
  dynamic_state[DYN_ROWS]
}

///|
pub fn dynamic_graph_iterations() -> Int {
  dynamic_state[DYN_ITERATIONS]
}

///|
pub fn dynamic_graph_nnz() -> Int {
  dynamic_state[DYN_NNZ]
}

///|
pub fn dynamic_row_ptr_addr() -> Int {
  dynamic_state[DYN_ROW_PTR_ADDR]
}

///|
pub fn dynamic_col_indices_addr() -> Int {
  dynamic_state[DYN_COL_INDICES_ADDR]
}
