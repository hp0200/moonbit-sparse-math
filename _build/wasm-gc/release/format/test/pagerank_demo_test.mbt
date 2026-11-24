///|
test "pagerank demo" {
  let transition : Array[Array[Double]] = [
    [0.0, 0.0, 1.0],
    [0.5, 0.0, 0.0],
    [0.5, 1.0, 0.0],
  ]
  let csr = @core.from_dense(transition, 0.0)

  let mut pr : Array[Double] = [0.333, 0.333, 0.333]
  let d = 0.85
  let node_count = pr.length()

  for iter = 0; iter < 20; iter = iter + 1 {
    let result = @core.spmv(csr, pr).unwrap()
    let next_pr : Array[Double] = []
    for i = 0; i < node_count; i = i + 1 {
      next_pr.push((1.0 - d) / 3.0 + d * result[i])
    }
    pr = next_pr
  }

  println("Final PageRank after 20 iterations: \{pr}")
}
