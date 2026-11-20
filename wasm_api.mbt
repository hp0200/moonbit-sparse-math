extern "wasm" fn store_f64(address : Int, value : Double) =
  #|(func (param i32 f64) (f64.store (local.get 0) (local.get 1)))

extern "wasm" fn allocate_linear_bytes(byte_count : Int) -> Int =
  #|(func (param i32) (result i32)
  #|  (local $pages i32)
  #|  (local $old_pages i32)
  #|  (local.set $pages
  #|    (i32.div_u
  #|      (i32.add (local.get 0) (i32.const 65535))
  #|      (i32.const 65536)))
  #|  (local.set $old_pages (memory.size))
  #|  (if (i32.eq (memory.grow (local.get $pages)) (i32.const -1))
  #|    (then (return (i32.const -1))))
  #|  (i32.shl (local.get $old_pages) (i32.const 16)))

pub fn run_sir_web_zero_copy() -> (Int, Int) {
  let days = 30
  let nodes = 10
  let element_count = days * nodes

  let dense : Array[Array[Double]] = []
  for i = 0; i < nodes; i = i + 1 {
    let row = Array::make(nodes, 0.0)
    row[i] = 0.8
    row[(i + 1) % nodes] = 0.1
    row[(i + 9) % nodes] = 0.1
    dense.push(row)
  }
  let matrix : SparseMatrix[Double] = from_dense(dense, 0.0)

  let mut infected : Array[Double] = Array::make(nodes, 0.0)
  infected[0] = 1.0

  let flat_data : Array[Double] = Array::make(element_count, 0.0)
  let mut index = 0
  for d = 0; d < days; d = d + 1 {
    for i = 0; i < nodes; i = i + 1 {
      flat_data[index] = infected[i]
      index = index + 1
    }
    infected = spmv(matrix, infected).unwrap()
  }

  let byte_count = element_count * 8
  let start_address = allocate_linear_bytes(byte_count)
  if start_address < 0 {
    abort("Failed to allocate Wasm linear memory")
  }

  let mut offset = 0
  for value in flat_data {
    store_f64(start_address + offset, value)
    offset = offset + 8
  }

  (start_address, element_count)
}

pub fn sir_result_ptr(result : (Int, Int)) -> Int {
  let (ptr, _) = result
  ptr
}

pub fn sir_result_count(result : (Int, Int)) -> Int {
  let (_, count) = result
  count
}
