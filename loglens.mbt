///|
pub enum Scalar {
  Text(String)
  Boolean(Bool)
  Numeric(Double)
}

///|
pub fn text(value : String) -> Scalar {
  Text(value)
}

///|
pub fn boolean(value : Bool) -> Scalar {
  Boolean(value)
}

///|
pub fn numeric(value : Double) -> Scalar {
  Numeric(value)
}

///|
pub struct Filter {
  path : String
  value : Scalar
}

///|
pub fn Filter::new(path : String, value : Scalar) -> Filter {
  { path, value, }
}

///|
pub fn make_filter(path : String, value : Scalar) -> Filter {
  Filter::new(path, value)
}

///|
pub struct Summary {
  matched : Int
  count : Int
  sum : Double
  min : Double?
  max : Double?
  average : Double?
}

///|
pub fn Summary::has_matches(self : Summary) -> Bool {
  self.matched > 0
}

///|
pub fn Summary::has_numeric_values(self : Summary) -> Bool {
  self.count > 0
}

///|
pub struct LogError {
  line : Int
  message : String
}

///|
pub fn LogError::to_string(self : LogError) -> String {
  if self.line > 0 {
    "line " + self.line.to_string() + ": " + self.message
  } else {
    self.message
  }
}

///|
fn error(line : Int, message : String) -> LogError {
  { line, message, }
}

///|
fn path_parts(path : String) -> Result[Array[String], LogError] {
  let parts = []
  for part_view in path.split(".") {
    let part = part_view.to_owned()
    if part == "" {
      return Err(error(0, "field path contains an empty component"))
    }
    parts.push(part)
  }
  if parts.length() == 0 {
    Err(error(0, "field path is empty"))
  } else {
    Ok(parts)
  }
}

///|
fn resolve(value : Json, parts : Array[String]) -> Json? {
  let mut current = value
  for part in parts {
    match current {
      Object(object) =>
        match object.get(part) {
          Some(next) => current = next
          None => return None
        }
      _ => return None
    }
  }
  Some(current)
}

///|
fn finite_number(number : Double) -> Bool {
  !number.is_nan() && !number.is_inf()
}

///|
fn scalar_value(value : Json, line : Int) -> Result[Scalar, LogError] {
  match value {
    String(text) => Ok(Text(text))
    True => Ok(Boolean(true))
    False => Ok(Boolean(false))
    Number(number, ..) if finite_number(number) => Ok(Numeric(number))
    Number(_, ..) => Err(error(line, "number is not finite"))
    _ => Err(error(line, "field value must be a string, boolean, or number"))
  }
}

///|
fn scalar_matches(
  actual : Json,
  expected : Scalar,
  line : Int,
) -> Result[Bool, LogError] {
  match scalar_value(actual, line) {
    Err(problem) => Err(problem)
    Ok(Text(actual_text)) =>
      match expected {
        Text(expected_text) => Ok(actual_text == expected_text)
        _ => Err(error(line, "filter value has an incompatible type"))
      }
    Ok(Boolean(actual_bool)) =>
      match expected {
        Boolean(expected_bool) => Ok(actual_bool == expected_bool)
        _ => Err(error(line, "filter value has an incompatible type"))
      }
    Ok(Numeric(actual_number)) =>
      match expected {
        Numeric(expected_number) => Ok(actual_number == expected_number)
        _ => Err(error(line, "filter value has an incompatible type"))
      }
  }
}

///|
pub fn parse_scalar(value : String) -> Result[Scalar, LogError] {
  try {
    let parsed = @json.parse(value)
    scalar_value(parsed, 0)
  } catch {
    _ =>
      if value.has_prefix("\"") ||
        value.has_prefix("[") ||
        value.has_prefix("{") {
        Err(error(0, "invalid JSON scalar"))
      } else {
        Ok(Text(value))
      }
  }
}

///|
fn add_number(
  summary : Summary,
  number : Double,
  line : Int,
) -> Result[Summary, LogError] {
  let next_sum = summary.sum + number
  if !finite_number(next_sum) {
    return Err(error(line, "numeric sum is not finite"))
  }
  let next_min = match summary.min {
    Some(old) => Some(if number < old { number } else { old })
    None => Some(number)
  }
  let next_max = match summary.max {
    Some(old) => Some(if number > old { number } else { old })
    None => Some(number)
  }
  let next_count = summary.count + 1
  let next_average = next_sum / next_count.to_double()
  if !finite_number(next_average) {
    return Err(error(line, "numeric average is not finite"))
  }
  Ok({
    matched: summary.matched,
    count: next_count,
    sum: next_sum,
    min: next_min,
    max: next_max,
    average: Some(next_average),
  })
}

///|
pub fn analyze_lines(
  lines : Iter[String],
  filter : Filter,
  numeric_path : String,
) -> Result[Summary, LogError] {
  let filter_parts = match path_parts(filter.path) {
    Ok(parts) => parts
    Err(problem) => return Err(problem)
  }
  let number_parts = match path_parts(numeric_path) {
    Ok(parts) => parts
    Err(problem) => return Err(problem)
  }
  let mut summary : Summary = {
    matched: 0,
    count: 0,
    sum: 0.0,
    min: None,
    max: None,
    average: None,
  }
  let mut line_number = 0
  for line in lines {
    line_number += 1
    let trimmed = line.trim().to_owned()
    if trimmed == "" {
      continue
    }
    let value = @json.parse(trimmed) catch {
      _ => return Err(error(line_number, "invalid JSON"))
    }
    if value is Object(_) {
      ()
    } else {
      return Err(error(line_number, "JSON line must be an object"))
    }
    let filter_value = match resolve(value, filter_parts) {
      Some(found) => found
      None => continue
    }
    let matches = match
      scalar_matches(filter_value, filter.value, line_number) {
      Ok(result) => result
      Err(problem) => return Err(problem)
    }
    if !matches {
      continue
    }
    summary = { ..summary, matched: summary.matched + 1, }
    let number = match resolve(value, number_parts) {
      Some(Number(number, ..)) if finite_number(number) => number
      Some(Number(_, ..)) =>
        return Err(error(line_number, "number is not finite"))
      Some(_) =>
        return Err(error(line_number, "numeric field must be a number"))
      None => continue
    }
    summary = match add_number(summary, number, line_number) {
      Ok(updated) => updated
      Err(problem) => return Err(problem)
    }
  }
  Ok(summary)
}

///|
pub fn analyze_jsonl(
  input : String,
  filter : Filter,
  numeric_path : String,
) -> Result[Summary, LogError] {
  analyze_lines(
    input.split("\n").map(line => line.to_owned()),
    filter,
    numeric_path,
  )
}
