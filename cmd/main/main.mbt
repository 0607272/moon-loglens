///|
fn usage() -> String {
  "usage: moon run --target js cmd/main -- stats <file-or-> <filter-path> <filter-value> <numeric-path>"
}

///|
fn optional_number(value : Double?) -> String {
  match value {
    Some(number) => number.to_string()
    None => "none"
  }
}

///|
fn report(summary : @loglens.Summary) -> String {
  "matched=" +
  summary.matched.to_string() +
  "\ncount=" +
  summary.count.to_string() +
  "\nsum=" +
  summary.sum.to_string() +
  "\nmin=" +
  optional_number(summary.min) +
  "\nmax=" +
  optional_number(summary.max) +
  "\naverage=" +
  optional_number(summary.average)
}

///|
fn fail(code : Int, message : String) -> Unit {
  write_stderr(message)
  set_exit_code(code)
}

///|
fn command_index(args : Array[String]) -> Int {
  for i, argument in args {
    if argument == "stats" {
      return i
    }
  }
  -1
}

///|
fn has_argument(args : Array[String], wanted : String) -> Bool {
  for argument in args {
    if argument == wanted {
      return true
    }
  }
  false
}

///|
fn run(args : Array[String]) -> Unit {
  if has_argument(args, "--version") {
    println("moon-loglens 0.1.0")
    return
  }
  if has_argument(args, "--help") || has_argument(args, "help") {
    println(usage())
    return
  }
  let start = command_index(args)
  if start < 0 {
    fail(2, usage())
    return
  }
  if args.length() < start + 5 {
    fail(2, usage())
    return
  }
  let input_path = args[start + 1]
  let filter_path = args[start + 2]
  match @loglens.parse_scalar(args[start + 3]) {
    Err(problem) => fail(2, "invalid filter value: " + problem.message)
    Ok(filter_value) => {
      let filter = @loglens.make_filter(filter_path, filter_value)
      match read_input(input_path) {
        Err(message) => fail(1, "input error: " + message)
        Ok(input) =>
          match @loglens.analyze_jsonl(input, filter, args[start + 4]) {
            Ok(summary) => println(report(summary))
            Err(problem) =>
              fail(
                1,
                "analysis error at line " +
                problem.line.to_string() +
                ": " +
                problem.message,
              )
          }
      }
    }
  }
}

///|
fn main {
  run(@env.args())
}
