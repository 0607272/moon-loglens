///|
test "report renders empty numeric values" {
  let filter = @loglens.make_filter("level", @loglens.text("error"))
  let summary = @loglens.analyze_jsonl(
    "{\"level\":\"error\"}", filter, "duration",
  ).unwrap()
  let output = report(summary)
  assert_true(output.contains("matched=1"))
  assert_true(output.contains("min=none"))
  assert_true(output.contains("average=none"))
}

///|
test "command detection ignores runtime prefixes" {
  assert_eq(command_index(["node", "runner", "stats", "file"]), 2)
  assert_eq(command_index(["node", "runner", "help"]), -1)
  assert_true(has_argument(["node", "runner", "--version"], "--version"))
}
