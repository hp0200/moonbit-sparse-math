///|
const MTX_HEADER : String = "%%MatrixMarket matrix coordinate real general"

///|
fn mtx_line_error(line_number : Int, message : String) -> String {
  "line \{line_number}: \{message}"
}

///|
fn mtx_tokens(line : StringView) -> Array[StringView] {
  let tokens : Array[StringView] = []
  let normalized = line.replace_all(old="\t", new=" ")
  for token in normalized.split(" ") {
    if token.length() > 0 {
      tokens.push(token)
    }
  }
  tokens
}

///|
fn is_mtx_header(tokens : Array[StringView]) -> Bool {
  tokens.length() == 5 &&
  tokens[0].to_lower().equal_to_string("%%matrixmarket") &&
  tokens[1].to_lower().equal_to_string("matrix") &&
  tokens[2].to_lower().equal_to_string("coordinate") &&
  tokens[3].to_lower().equal_to_string("real") &&
  tokens[4].to_lower().equal_to_string("general")
}

///|
fn parse_mtx_text(content : String) -> Result[SparseMatrix[Double], String] {
  let values : Array[Double] = []
  let row_indices : Array[Int32] = []
  let col_indices : Array[Int32] = []
  let mut line_number = 0
  let mut header_seen = false
  let mut dimensions_seen = false
  let mut rows : Int32 = 0
  let mut cols : Int32 = 0
  let mut expected_nnz : Int32 = 0
  let mut parsed_nnz : Int32 = 0

  for raw_line in content.split("\n") {
    line_number = line_number + 1
    let line = raw_line.trim()
    if line.length() == 0 {
      continue
    }
    if !header_seen {
      let tokens = mtx_tokens(line)
      if !is_mtx_header(tokens) {
        return Err(
          mtx_line_error(line_number, "expected header '\{MTX_HEADER}'"),
        )
      }
      header_seen = true
      continue
    }
    if line.has_prefix("%") {
      continue
    }
    let tokens = mtx_tokens(line)
    if !dimensions_seen {
      if tokens.length() != 3 {
        return Err(
          mtx_line_error(
            line_number,
            "expected three integers: rows cols nnz",
          ),
        )
      }
      rows = @string.parse_int(tokens[0]) catch {
        _ => return Err(mtx_line_error(line_number, "invalid row count"))
      }
      cols = @string.parse_int(tokens[1]) catch {
        _ => return Err(mtx_line_error(line_number, "invalid column count"))
      }
      expected_nnz = @string.parse_int(tokens[2]) catch {
        _ => return Err(mtx_line_error(line_number, "invalid nnz count"))
      }
      if rows < 0 || cols < 0 || expected_nnz < 0 {
        return Err(
          mtx_line_error(
            line_number,
            "rows, columns, and nnz must be non-negative",
          ),
        )
      }
      dimensions_seen = true
      continue
    }
    if parsed_nnz >= expected_nnz {
      return Err(mtx_line_error(line_number, "more entries than declared nnz"))
    }
    if tokens.length() != 3 {
      return Err(
        mtx_line_error(
          line_number,
          "expected entry triplet: row column value",
        ),
      )
    }
    let row = @string.parse_int(tokens[0]) catch {
      _ => return Err(mtx_line_error(line_number, "invalid row index"))
    }
    let col = @string.parse_int(tokens[1]) catch {
      _ => return Err(mtx_line_error(line_number, "invalid column index"))
    }
    if row < 1 || row > rows {
      return Err(
        mtx_line_error(
          line_number,
          "row index \{row} is outside 1..\{rows}",
        ),
      )
    }
    if col < 1 || col > cols {
      return Err(
        mtx_line_error(
          line_number,
          "column index \{col} is outside 1..\{cols}",
        ),
      )
    }
    let value = @string.parse_double(tokens[2]) catch {
      _ => return Err(mtx_line_error(line_number, "invalid matrix value"))
    }
    values.push(value)
    row_indices.push(row - 1)
    col_indices.push(col - 1)
    parsed_nnz = parsed_nnz + 1
  }

  if !header_seen {
    return Err("empty Matrix Market file or missing header")
  }
  if !dimensions_seen {
    return Err("missing Matrix Market size line")
  }
  if parsed_nnz != expected_nnz {
    return Err("expected \{expected_nnz} entries, but found \{parsed_nnz}")
  }

  let coo = CooMatrix::{ values, row_indices, col_indices, rows, cols }
  Ok(from_coo(coo))
}

///|
#cfg(any(target="native", target="wasm"))
fn read_mtx_file(path : String) -> Result[String, String] {
  let text : Array[String] = [""]
  let errors : Array[String] = []
  @runtime.with_event_loop(() => {
    try @fs.read_text(path) catch {
      err => errors.push(err.to_string())
    } noraise {
      content => text[0] = content
    }
  }) catch {
    err => return Err("failed to initialize file I/O: \{err}")
  }
  if errors.length() > 0 {
    Err(errors[0])
  } else {
    Ok(text[0])
  }
}

///|
#cfg(any(target="native", target="wasm"))
fn write_mtx_file(path : String, content : String) -> Result[Unit, String] {
  let errors : Array[String] = []
  @runtime.with_event_loop(() => {
    try @fs.write_text(path, content) catch {
      err => errors.push(err.to_string())
    } noraise {
      _ => ()
    }
  }) catch {
    err => return Err("failed to initialize file I/O: \{err}")
  }
  if errors.length() > 0 {
    Err(errors[0])
  } else {
    Ok(())
  }
}

///|
#cfg(not(any(target="native", target="wasm")))
fn read_mtx_file(_path : String) -> Result[String, String] {
  Err("Matrix Market file I/O is unavailable on this target")
}

///|
#cfg(not(any(target="native", target="wasm")))
fn write_mtx_file(_path : String, _content : String) -> Result[Unit, String] {
  Err("Matrix Market file I/O is unavailable on this target")
}

///|
pub fn read_mtx(path : String) -> Result[SparseMatrix[Double], String] {
  let content = match read_mtx_file(path) {
    Ok(content) => content
    Err(message) => return Err(message)
  }
  parse_mtx_text(content)
}

///|
pub fn write_mtx(
  csr : SparseMatrix[Double],
  path : String,
) -> Result[Unit, String] {
  if csr.row_ptr.length() == 0 {
    return Err("invalid CSR matrix: row_ptr is empty")
  }
  if csr.values.length() != csr.col_indices.length() {
    return Err("invalid CSR matrix: values and col_indices differ in length")
  }
  if csr.row_ptr[0] != 0 {
    return Err("invalid CSR matrix: row_ptr must start at zero")
  }
  let rows = csr.row_ptr.length() - 1
  let mut cols : Int32 = 0
  for pos = 0; pos < csr.values.length(); pos = pos + 1 {
    let col = csr.col_indices[pos]
    if col < 0 {
      return Err("invalid CSR matrix: negative column index")
    }
    if col + 1 > cols {
      cols = col + 1
    }
  }
  for row = 0; row < rows; row = row + 1 {
    let start = csr.row_ptr[row]
    let end = csr.row_ptr[row + 1]
    if start < 0 || end < start || end > csr.values.length() {
      return Err("invalid CSR matrix: row_ptr is not monotonic")
    }
  }
  if csr.row_ptr[rows] != csr.values.length() {
    return Err("invalid CSR matrix: row_ptr does not cover all values")
  }

  let builder = StringBuilder()
  builder.write_string("\{MTX_HEADER}\n")
  builder.write_string("\{rows} \{cols} \{csr.values.length()}\n")
  for row = 0; row < rows; row = row + 1 {
    for pos = csr.row_ptr[row]; pos < csr.row_ptr[row + 1]; pos = pos + 1 {
      builder.write_string(
        "\{row + 1} \{csr.col_indices[pos] + 1} \{csr.values[pos].to_string()}\n",
      )
    }
  }
  write_mtx_file(path, builder.to_string())
}
