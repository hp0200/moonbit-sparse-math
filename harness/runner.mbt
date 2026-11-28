///|
pub(all) struct PropertyFailure {
  matrix : String
  property : String
  message : String
}

///|
pub(all) struct PropertyReport {
  timestamp : String
  seed : Int32
  scale : String
  total : Int32
  passed : Int32
  failed : Int32
  failures : Array[PropertyFailure]
}

///|
fn runner_options(
  args : Array[String],
) -> Result[(Int32, String, String?), String] {
  let mut seed = 42
  let mut scale = "small"
  let mut output : String? = None
  for arg in args {
    if arg.has_prefix("--seed=") {
      let value = match arg.strip_prefix("--seed=") {
        Some(text) => text
        None => return Err("invalid --seed argument: expected --seed=<integer>")
      }
      let parsed = @string.parse_int(value) catch {
        _ => return Err("invalid --seed value: \{value}")
      }
      seed = parsed
    } else if arg.has_prefix("--scale=") {
      let value = match arg.strip_prefix("--scale=") {
        Some(text) => text
        None =>
          return Err(
            "invalid --scale argument: expected --scale=<small|medium>",
          )
      }
      scale = value.to_owned()
    } else if arg.has_prefix("--output=") {
      let value = match arg.strip_prefix("--output=") {
        Some(text) => text
        None =>
          return Err("invalid --output argument: expected --output=<path>")
      }
      output = Some(value.to_owned())
    } else if arg.has_prefix("--") {
      return Err("unknown argument: \{arg}")
    }
  }
  if scale != "small" && scale != "medium" {
    return Err("invalid --scale value '\{scale}': expected small or medium")
  }
  Ok((seed, scale, output))
}

///|
/// Executes the full corpus x property Cartesian product.
pub fn execute(seed : Int32, scale : String) -> Result[PropertyReport, String] {
  if scale != "small" && scale != "medium" {
    return Err("invalid scale '\{scale}': expected small or medium")
  }
  let cases = corpus(scale, seed)
  let properties = all_properties()
  let failures : Array[PropertyFailure] = []
  let mut total = 0
  let mut passed = 0
  let mut failed = 0
  for corpus_case in cases {
    for property in properties {
      total = total + 1
      match (property.check)(corpus_case.matrix) {
        Ok(_) => passed = passed + 1
        Err(message) => {
          failed = failed + 1
          failures.push(PropertyFailure::{
            matrix: corpus_case.name,
            property: property.name,
            message,
          })
        }
      }
    }
  }
  Ok(PropertyReport::{
    timestamp: @env.now().to_string(),
    seed,
    scale,
    total,
    passed,
    failed,
    failures,
  })
}

///|
pub fn report_to_json(report : PropertyReport) -> String {
  let failures : Array[@json.Json] = []
  for failure in report.failures {
    failures.push(
      @json.Json::object({
        "matrix": @json.Json::string(failure.matrix),
        "property": @json.Json::string(failure.property),
        "message": @json.Json::string(failure.message),
      }),
    )
  }
  @json.Json::object({
    "timestamp": @json.Json::string(report.timestamp),
    "seed": @json.Json::number(report.seed.to_double()),
    "scale": @json.Json::string(report.scale),
    "total": @json.Json::number(report.total.to_double()),
    "passed": @json.Json::number(report.passed.to_double()),
    "failed": @json.Json::number(report.failed.to_double()),
    "failures": @json.Json::array(failures),
  }).stringify(indent=2)
}

///|
#warnings("-alert_internal")
#cfg(any(target="native", target="wasm"))
fn runner_write_file(path : String, content : String) -> Result[Unit, String] {
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
fn runner_write_file(_path : String, _content : String) -> Result[Unit, String] {
  Err("--output is unavailable on this target")
}

///|
/// CLI entry point used by the `harness/runner` executable package.
pub fn runner_main(args : Array[String]) -> Unit {
  let (seed, scale, output) = match runner_options(args) {
    Ok(options) => options
    Err(message) => {
      println("error: \{message}")
      @env.exit(2)
    }
  }
  let report = match execute(seed, scale) {
    Ok(value) => value
    Err(message) => {
      println("error: \{message}")
      @env.exit(2)
    }
  }
  let json = report_to_json(report)
  println(json)
  match output {
    Some(path) =>
      match runner_write_file(path, json) {
        Ok(_) => ()
        Err(message) => {
          println("error: failed to write report to \{path}: \{message}")
          @env.exit(2)
        }
      }
    None => ()
  }
  if report.failed > 0 {
    @env.exit(1)
  }
}
