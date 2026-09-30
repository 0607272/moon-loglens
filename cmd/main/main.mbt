///|
fn usage() -> String {
  "usage:\n  moon run --target js cmd/main -- stats <file-or-> <filter-path> <filter-value> <numeric-path>\n  moon run --target js cmd/main -- profile <file-or-> <path1,path2,...>\n  moon run --target js cmd/main -- group <file-or-> <group-path> <numeric-path>"
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
fn profile_report(profiles : Array[@loglens.FieldProfile]) -> String {
  let output = StringBuilder()
  for i, profile in profiles {
    if i > 0 {
      output.write("\n")
    }
    output.write("path=" + profile.path)
    output.write("\nrecords=" + profile.records.to_string())
    output.write("\npresent=" + profile.present().to_string())
    output.write("\nmissing=" + profile.missing.to_string())
    output.write("\nnull=" + profile.nulls.to_string())
    output.write("\ntext=" + profile.texts.to_string())
    output.write("\nboolean=" + profile.booleans.to_string())
    output.write("\nnumeric=" + profile.numerics.to_string())
    output.write("\nobject=" + profile.objects.to_string())
    output.write("\narray=" + profile.arrays.to_string())
  }
  output.to_string()
}

///|
fn group_report(groups : Array[@loglens.GroupSummary]) -> String {
  let output = StringBuilder()
  for i, group in groups {
    if i > 0 {
      output.write("\n")
    }
    output.write("key=" + group.key_text())
    output.write("\nmatched=" + group.matched.to_string())
    output.write("\ncount=" + group.count.to_string())
    output.write("\nsum=" + group.sum.to_string())
    output.write("\nmin=" + optional_number(group.min))
    output.write("\nmax=" + optional_number(group.max))
    output.write("\naverage=" + optional_number(group.average))
  }
  output.to_string()
}

///|
fn paths_argument(value : String) -> Array[String] {
  let result : Array[String] = []
  for path in value.split(",") {
    result.push(path.to_owned())
  }
  result
}

///|
fn fail(code : Int, message : String) -> Unit {
  write_stderr(message)
  set_exit_code(code)
}

///|
fn command_index(args : Array[String]) -> Int {
  for i, argument in args {
    if argument == "stats" || argument == "profile" || argument == "group" {
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
  if args[start] == "profile" {
    if args.length() < start + 3 {
      fail(2, usage())
      return
    }
    match read_input(args[start + 1]) {
      Err(message) => fail(1, "input error: " + message)
      Ok(input) =>
        match @loglens.profile_jsonl(input, paths_argument(args[start + 2])) {
          Ok(profiles) => println(profile_report(profiles))
          Err(problem) => fail(1, "analysis error: " + problem.to_string())
        }
    }
    return
  }
  if args[start] == "group" {
    if args.length() < start + 4 {
      fail(2, usage())
      return
    }
    match read_input(args[start + 1]) {
      Err(message) => fail(1, "input error: " + message)
      Ok(input) =>
        match @loglens.group_jsonl(input, args[start + 2], args[start + 3]) {
          Ok(groups) => println(group_report(groups))
          Err(problem) => fail(1, "analysis error: " + problem.to_string())
        }
    }
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
