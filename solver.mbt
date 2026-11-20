///|
fn dot_product(a : Array[Double], b : Array[Double]) -> Double {
  let mut sum = 0.0
  for i = 0; i < a.length(); i = i + 1 {
    sum = sum + a[i] * b[i]
  }
  sum
}

///|
pub fn cg_solve(
  a : SparseMatrix[Double],
  b : Array[Double],
  tol : Double,
) -> Array[Double] {
  let n = b.length()
  let x : Array[Double] = []
  let r : Array[Double] = []
  let p : Array[Double] = []

  for i = 0; i < n; i = i + 1 {
    x.push(0.0)
    r.push(b[i])
    p.push(b[i])
  }

  let mut rsold = dot_product(r, r)
  let mut iter = 0

  while iter < n * 2 {
    let ap = spmv(a, p).unwrap()
    let pap = dot_product(p, ap)

    if pap == 0.0 {
      break
    }

    let alpha = rsold / pap

    for i = 0; i < n; i = i + 1 {
      x[i] = x[i] + alpha * p[i]
      r[i] = r[i] - alpha * ap[i]
    }

    let rsnew = dot_product(r, r)
    if rsnew < tol * tol {
      break
    }

    let beta = rsnew / rsold
    for i = 0; i < n; i = i + 1 {
      p[i] = r[i] + beta * p[i]
    }

    rsold = rsnew
    iter = iter + 1
  }

  x
}

///|
pub fn pcg_solve(
  a : SparseMatrix[Double],
  b : Array[Double],
  tol : Double,
  max_iter : Int,
) -> Result[Array[Double], String] {
  let n = b.length()
  let rows = a.row_ptr.length() - 1
  if n == 0 || n != rows {
    return Err("Matrix is singular or dimension mismatch")
  }

  let m_inv : Array[Double] = Array::make(n, 0.0)
  for i = 0; i < n; i = i + 1 {
    let mut diagonal_found = false
    let mut diagonal = 0.0
    for k = a.row_ptr[i]; k < a.row_ptr[i + 1]; k = k + 1 {
      if a.col_indices[k] == i {
        diagonal = a.values[k]
        diagonal_found = true
      }
    }
    if !diagonal_found || diagonal == 0.0 {
      return Err("Matrix is singular or dimension mismatch")
    }
    m_inv[i] = 1.0 / diagonal
  }

  let x : Array[Double] = Array::make(n, 0.0)
  let r : Array[Double] = Array::make(n, 0.0)
  let z : Array[Double] = Array::make(n, 0.0)
  let p : Array[Double] = Array::make(n, 0.0)

  for i = 0; i < n; i = i + 1 {
    r[i] = b[i]
    z[i] = m_inv[i] * r[i]
    p[i] = z[i]
  }

  let b_norm_sq = dot_product(b, b)
  let scale = if b_norm_sq > 1.0 { b_norm_sq } else { 1.0 }
  let effective_tol = tol.abs()
  let threshold = effective_tol * effective_tol * scale
  let mut residual_sq = dot_product(r, r)
  let mut rz = dot_product(r, z)
  let mut iter = 0

  if residual_sq <= threshold {
    return Ok(x)
  }
  if rz <= 0.0 {
    return Err("Matrix is singular or dimension mismatch")
  }

  while iter < max_iter {
    let ap = match spmv(a, p) {
      Ok(value) => value
      Err(_) => return Err("Matrix is singular or dimension mismatch")
    }
    let pap = dot_product(p, ap)
    if pap <= 0.0 {
      return Err("Matrix is singular or dimension mismatch")
    }

    let alpha = rz / pap
    for i = 0; i < n; i = i + 1 {
      x[i] = x[i] + alpha * p[i]
      r[i] = r[i] - alpha * ap[i]
    }

    residual_sq = dot_product(r, r)
    if residual_sq <= threshold {
      return Ok(x)
    }

    for i = 0; i < n; i = i + 1 {
      z[i] = m_inv[i] * r[i]
    }
    let rz_new = dot_product(r, z)
    if rz_new <= 0.0 {
      return Err("Matrix is singular or dimension mismatch")
    }

    let beta = rz_new / rz
    for i = 0; i < n; i = i + 1 {
      p[i] = z[i] + beta * p[i]
    }
    rz = rz_new
    iter = iter + 1
  }

  Err("Did not converge")
}
