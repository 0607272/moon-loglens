///|
test "summarizes only matching events" {
  let result = @moon-loglens.analyze_jsonl(
    "{\"level\":\"error\",\"duration\":2}\n{\"level\":\"info\",\"duration\":100}\n{\"level\":\"error\",\"duration\":4}\n",
    @moon-loglens.make_filter("level", @moon-loglens.text("error")),
    "duration",
  ).unwrap()
  assert_eq(result.matched, 2)
  assert_eq(result.count, 2)
  assert_eq(result.sum, 6.0)
  assert_eq(result.min, Some(2.0))
  assert_eq(result.max, Some(4.0))
  assert_eq(result.average, Some(3.0))
  assert_true(result.has_matches())
  assert_true(result.has_numeric_values())
}

///|
test "empty input has explicit empty statistics" {
  let result = @moon-loglens.analyze_jsonl(
    " \r\n\t\n",
    @moon-loglens.make_filter("level", @moon-loglens.text("error")),
    "duration",
  ).unwrap()
  assert_eq(result.count, 0)
  assert_eq(result.matched, 0)
  assert_eq(result.sum, 0.0)
  assert_eq(result.min, None)
  assert_eq(result.max, None)
  assert_eq(result.average, None)
  assert_true(!result.has_matches())
  assert_true(!result.has_numeric_values())
}

///|
test "missing fields and nonmatching numeric types are skipped" {
  let result = @moon-loglens.analyze_jsonl(
    "{}\n{\"level\":\"error\"}\n{\"level\":\"info\",\"duration\":\"bad\"}\n{\"level\":\"error\",\"duration\":-5}\n",
    @moon-loglens.make_filter("level", @moon-loglens.text("error")),
    "duration",
  ).unwrap()
  assert_eq(result.matched, 2)
  assert_eq(result.count, 1)
  assert_eq(result.average, Some(-5.0))
}

///|
test "nested boolean and numeric filters" {
  let input = "{\"meta\":{\"ok\":true,\"status\":200},\"value\":1.5}\r\n{\"meta\":{\"ok\":false,\"status\":500},\"value\":-2.5}\n"
  let result = @moon-loglens.analyze_jsonl(
    input,
    @moon-loglens.make_filter("meta.ok", @moon-loglens.boolean(true)),
    "value",
  ).unwrap()
  assert_eq(result.count, 1)
  assert_eq(result.sum, 1.5)
  let numeric = @moon-loglens.analyze_jsonl(
    input,
    @moon-loglens.make_filter("meta.status", @moon-loglens.numeric(500.0)),
    "value",
  ).unwrap()
  assert_eq(numeric.sum, -2.5)
}

///|
test "errors retain physical line numbers" {
  let filter : @moon-loglens.Filter = @moon-loglens.make_filter(
    "level",
    @moon-loglens.text("error"),
  )
  let bad = @moon-loglens.analyze_jsonl("\n{}\nnot json", filter, "duration")
  assert_true(bad is Err({ line: 3, .. }))
  assert_true(
    @moon-loglens.analyze_jsonl("[]", filter, "duration")
    is Err({ line: 1, .. }),
  )
  assert_true(
    @moon-loglens.analyze_jsonl("{\"level\":1}", filter, "duration")
    is Err({ line: 1, .. }),
  )
  assert_true(
    @moon-loglens.analyze_jsonl(
      "{\"level\":\"error\",\"duration\":null}", filter, "duration",
    )
    is Err({ line: 1, .. }),
  )
}

///|
test "invalid paths and scalar values fail before reading input" {
  assert_true(
    @moon-loglens.analyze_jsonl(
      "",
      @moon-loglens.make_filter("a..b", @moon-loglens.text("x")),
      "v",
    )
    is Err({ line: 0, .. }),
  )
  assert_true(
    @moon-loglens.analyze_jsonl(
      "",
      @moon-loglens.make_filter("a", @moon-loglens.text("x")),
      "",
    )
    is Err({ line: 0, .. }),
  )
  assert_true(@moon-loglens.parse_scalar("error") is Ok(_))
  assert_true(@moon-loglens.parse_scalar("\"true\"") is Ok(_))
  assert_true(@moon-loglens.parse_scalar("true") is Ok(_))
  assert_true(@moon-loglens.parse_scalar("-2.5") is Ok(_))
  assert_true(@moon-loglens.parse_scalar("null") is Err(_))
  assert_true(@moon-loglens.parse_scalar("[]") is Err(_))
  assert_true(@moon-loglens.parse_scalar("\"broken") is Err(_))
}

///|
test "errors have stable user-facing text" {
  let filter = @moon-loglens.make_filter("level", @moon-loglens.text("error"))
  let problem = @moon-loglens.analyze_jsonl("bad", filter, "value").unwrap_err()
  assert_eq(problem.to_string(), "line 1: invalid JSON")
  let global = @moon-loglens.analyze_jsonl(
    "",
    @moon-loglens.make_filter("a..b", @moon-loglens.text("x")),
    "v",
  ).unwrap_err()
  assert_eq(global.to_string(), "field path contains an empty component")
}

///|
test "supports unicode text and exponent numbers" {
  let input = "{\"service\":\"搜索\",\"size\":1.5e1}\n{\"service\":\"skip\",\"size\":2}\n"
  let result = @moon-loglens.analyze_jsonl(
    input,
    @moon-loglens.make_filter("service", @moon-loglens.text("搜索")),
    "size",
  ).unwrap()
  assert_eq(result.count, 1)
  assert_eq(result.sum, 15.0)
}

///|
test "counts CRLF blank lines in reported locations" {
  let filter = @moon-loglens.make_filter("level", @moon-loglens.text("error"))
  let problem = @moon-loglens.analyze_jsonl(
    "\r\n{\"level\":\"error\"}\r\nnope", filter, "value",
  ).unwrap_err()
  assert_eq(problem.line, 3)
  assert_eq(problem.to_string(), "line 3: invalid JSON")
}

///|
test "iterator and text APIs agree" {
  let input = "{\"level\":\"error\",\"value\":7}\n\n{\"level\":\"error\",\"value\":3}"
  let filter : @moon-loglens.Filter = @moon-loglens.make_filter(
    "level",
    @moon-loglens.text("error"),
  )
  let by_lines = @moon-loglens.analyze_lines(
    input.split("\n").map(line => line.to_owned()),
    filter,
    "value",
  ).unwrap()
  let by_text = @moon-loglens.analyze_jsonl(input, filter, "value").unwrap()
  assert_eq(by_lines.count, by_text.count)
  assert_eq(by_lines.sum, by_text.sum)
}

///|
test "nonfinite numbers and sum overflow are errors" {
  let filter : @moon-loglens.Filter = @moon-loglens.make_filter(
    "ok",
    @moon-loglens.boolean(true),
  )
  assert_true(
    @moon-loglens.analyze_jsonl("{\"ok\":true,\"v\":1e999}", filter, "v")
    is Err(_),
  )
  assert_true(
    @moon-loglens.analyze_jsonl(
      "{\"ok\":true,\"v\":1e308}\n{\"ok\":true,\"v\":1e308}", filter, "v",
    )
    is Err({ line: 2, .. }),
  )
  assert_true(@moon-loglens.parse_scalar("1e999") is Err(_))
}
