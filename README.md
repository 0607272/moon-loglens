# moon-loglens

`moon-loglens` is a MoonBit library and command-line tool for filtering JSON
Lines records, profiling fields, grouping events, and calculating numeric
summaries.

## Requirements

- MoonBit with `moonc` 0.10.14 or newer
- Node.js for the JavaScript CLI target

## CLI

Run the checked-in example:

```text
moon run --target js cmd/main -- stats examples/basic/events.jsonl level error duration_ms
```

The output contains `matched`, numeric `count`, `sum`, `min`, `max`, and
`average`. Use `-` as the input path to read standard input:

```text
Get-Content examples/basic/events.jsonl | moon run --target js cmd/main -- stats - level error duration_ms
```

Use `--help` for the command synopsis and `--version` to print the module
version. The CLI returns exit code 2 for usage or filter syntax errors and exit
code 1 for file, JSON, or analysis errors.

Profile several fields at once to inspect missing values and JSON kinds:

```text
moon run --target js cmd/main -- profile examples/basic/events.jsonl level,duration_ms,request.status
```

Group records by a scalar field and calculate a numeric summary for each
group:

```text
moon run --target js cmd/main -- group examples/basic/events.jsonl service duration_ms
```

Filter values are plain strings by default. JSON booleans, numbers, and quoted
strings keep their types, so `true`, `-2.5`, and `"error"` are distinct values.
Field paths use dot-separated object keys, such as `request.status`.

Missing filter fields skip a record. A matching record with a missing numeric
field is counted as matched but contributes no numeric value. Present fields
with incompatible types are errors. Empty numeric selections report `none` for
minimum, maximum, and average.

## Library

```moonbit
let filter = @moon-loglens.make_filter("level", @moon-loglens.text("error"))
let result = @moon-loglens.analyze_jsonl(
  "{\"level\":\"error\",\"duration_ms\":12}\n",
  filter,
  "duration_ms",
).unwrap()
assert_eq(result.average, Some(12.0))
```

`analyze_lines` accepts an iterator of lines for callers that already stream
input. `analyze_jsonl` is the convenient complete-text helper. Both return a
structured `LogError` with a physical one-based source line.

`profile_lines` and `profile_jsonl` return per-path `FieldProfile` values with
presence, missing, null, scalar, object, and array counts. `group_lines` and
`group_jsonl` return ordered `GroupSummary` values for scalar group keys.

## Development

```text
moon fmt
moon info
moon check --target js --deny-warn
moon build --target js --deny-warn
moon test --target js --deny-warn
```

The project uses only the MoonBit core JSON package. The example data is
synthetic and contains no personal or production log data. The project is an
independent implementation and does not copy a third-party source tree.

## Scope

The current release supports one scalar equality filter, multi-field profiling,
scalar grouping, and one numeric summary per group. Field paths address nested
objects with dot-separated keys. Arrays can be classified by profiling but are
not traversed as path components. The tool does not implement joins, arbitrary
expressions, network ingestion, or in-place rewriting.
