///|
test "report renders empty numeric values" {
  let summary : @loglens.Summary = {
    matched: 2,
    count: 0,
    sum: 0.0,
    min: None,
    max: None,
    average: None,
  }
  let output = report(summary)
  assert_true(output.contains("matched=2"))
  assert_true(output.contains("min=none"))
  assert_true(output.contains("average=none"))
}

///|
test "command detection ignores runtime prefixes" {
  assert_eq(command_index(["node", "runner", "stats", "file"]), 2)
  assert_eq(command_index(["node", "runner", "help"]), -1)
  assert_true(has_argument(["node", "runner", "--version"], "--version"))
}
