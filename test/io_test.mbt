///|
test "mtx write read round trip" {
  let dense : Array[Array[Double]] = [
    [1.5, 0.0, 0.0],
    [0.0, -2.25, 0.0],
    [0.0, 0.0, 3.0],
  ]
  let original = @core.from_dense(dense, 0.0)
  let path = "_build/mtx_io_roundtrip_test.mtx"
  match @core.write_mtx(original, path) {
    Ok(_) => ()
    Err(message) => fail("write_mtx failed: \{message}")
  }
  match @core.read_mtx(path) {
    Ok(parsed) => {
      assert_eq(parsed.row_ptr, original.row_ptr)
      assert_eq(parsed.col_indices, original.col_indices)
      assert_eq(parsed.values, original.values)
    }
    Err(message) => fail("read_mtx failed: \{message}")
  }
}
