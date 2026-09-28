///|
fn main {
  let input = "{\"level\":\"error\",\"duration_ms\":12}\n{\"level\":\"error\",\"duration_ms\":28}\n"
  let filter = @loglens.make_filter("level", @loglens.text("error"))
  let summary = @loglens.analyze_jsonl(input, filter, "duration_ms").unwrap()
  println("errors=" + summary.count.to_string())
  println("average_duration_ms=" + summary.average.unwrap().to_string())
}
