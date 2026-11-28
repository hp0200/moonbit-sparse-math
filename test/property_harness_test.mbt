///|
test "property harness small corpus has no failures" {
  let report = match @harness.execute(42, "small") {
    Ok(value) => value
    Err(message) => fail("property harness setup failed: \{message}")
  }
  assert_eq(report.total, 60)
  assert_eq(report.failed, 0)
}
