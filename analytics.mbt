///|
pub enum FieldKind {
  Missing
  Null
  Text
  Boolean
  Numeric
  Object
  Array
}

///|
pub struct FieldProfile {
  path : String
  records : Int
  missing : Int
  nulls : Int
  texts : Int
  booleans : Int
  numerics : Int
  objects : Int
  arrays : Int
}

///|
pub fn FieldProfile::present(self : FieldProfile) -> Int {
  self.records - self.missing
}

///|
pub fn FieldProfile::kind_count(self : FieldProfile, kind : FieldKind) -> Int {
  match kind {
    Missing => self.missing
    Null => self.nulls
    Text => self.texts
    Boolean => self.booleans
    Numeric => self.numerics
    Object => self.objects
    Array => self.arrays
  }
}

///|
fn increment_kind(profile : FieldProfile, kind : FieldKind) -> FieldProfile {
  match kind {
    Missing => { ..profile, missing: profile.missing + 1, }
    Null => { ..profile, nulls: profile.nulls + 1, }
    Text => { ..profile, texts: profile.texts + 1, }
    Boolean => { ..profile, booleans: profile.booleans + 1, }
    Numeric => { ..profile, numerics: profile.numerics + 1, }
    Object => { ..profile, objects: profile.objects + 1, }
    Array => { ..profile, arrays: profile.arrays + 1, }
  }
}

///|
fn field_kind(value : Json?) -> FieldKind {
  match value {
    None => Missing
    Some(Null) => Null
    Some(String(_)) => Text
    Some(True | False) => Boolean
    Some(Number(_, ..)) => Numeric
    Some(Object(_)) => Object
    Some(Array(_)) => Array
  }
}

///|
fn validate_paths(
  paths : Array[String],
) -> Result[Array[Array[String]], LogError] {
  let result : Array[Array[String]] = []
  for path in paths {
    match path_parts(path) {
      Ok(parts) => result.push(parts)
      Err(problem) => return Err(problem)
    }
  }
  Ok(result)
}

///|
fn parse_object_line(
  line : String,
  line_number : Int,
) -> Result[Json, LogError] {
  let value = @json.parse(line.trim().to_owned()) catch {
    _ => return Err(error(line_number, "invalid JSON"))
  }
  if value is Object(_) {
    Ok(value)
  } else {
    Err(error(line_number, "JSON line must be an object"))
  }
}

///|
pub fn profile_lines(
  lines : Iter[String],
  paths : Array[String],
) -> Result[Array[FieldProfile], LogError] {
  let path_parts_list = match validate_paths(paths) {
    Ok(parts) => parts
    Err(problem) => return Err(problem)
  }
  let profiles : Array[FieldProfile] = []
  for path in paths {
    profiles.push({
      path,
      records: 0,
      missing: 0,
      nulls: 0,
      texts: 0,
      booleans: 0,
      numerics: 0,
      objects: 0,
      arrays: 0,
    })
  }
  let mut line_number = 0
  for line in lines {
    line_number += 1
    if line.trim() == "" {
      continue
    }
    let value = match parse_object_line(line, line_number) {
      Ok(value) => value
      Err(problem) => return Err(problem)
    }
    for i, parts in path_parts_list {
      let kind = field_kind(resolve(value, parts))
      let profile = profiles[i]
      profiles[i] = increment_kind(
        { ..profile, records: profile.records + 1, },
        kind,
      )
    }
  }
  Ok(profiles)
}

///|
pub fn profile_jsonl(
  input : String,
  paths : Array[String],
) -> Result[Array[FieldProfile], LogError] {
  profile_lines(input.split("\n").map(line => line.to_owned()), paths)
}

///|
pub struct GroupSummary {
  key : Scalar
  matched : Int
  count : Int
  sum : Double
  min : Double?
  max : Double?
  average : Double?
}

///|
pub fn GroupSummary::key_text(self : GroupSummary) -> String {
  match self.key {
    Text(value) => value
    Boolean(value) => value.to_string()
    Numeric(value) => value.to_string()
  }
}

///|
fn scalar_key(value : Scalar) -> String {
  match value {
    Text(text) => "text:" + text
    Boolean(value) => "bool:" + value.to_string()
    Numeric(value) => "number:" + value.to_string()
  }
}

///|
fn group_index(groups : Array[GroupSummary], key : Scalar) -> Int? {
  let wanted = scalar_key(key)
  for i, group in groups {
    if scalar_key(group.key) == wanted {
      return Some(i)
    }
  }
  None
}

///|
pub fn group_lines(
  lines : Iter[String],
  group_path : String,
  numeric_path : String,
) -> Result[Array[GroupSummary], LogError] {
  let group_parts = match path_parts(group_path) {
    Ok(parts) => parts
    Err(problem) => return Err(problem)
  }
  let number_parts = match path_parts(numeric_path) {
    Ok(parts) => parts
    Err(problem) => return Err(problem)
  }
  let groups : Array[GroupSummary] = []
  let mut line_number = 0
  for line in lines {
    line_number += 1
    if line.trim() == "" {
      continue
    }
    let value = match parse_object_line(line, line_number) {
      Ok(value) => value
      Err(problem) => return Err(problem)
    }
    let group_value = match resolve(value, group_parts) {
      Some(found) =>
        match scalar_value(found, line_number) {
          Ok(scalar) => scalar
          Err(problem) => return Err(problem)
        }
      None => continue
    }
    let index = match group_index(groups, group_value) {
      Some(found) => found
      None => {
        groups.push({
          key: group_value,
          matched: 0,
          count: 0,
          sum: 0.0,
          min: None,
          max: None,
          average: None,
        })
        groups.length() - 1
      }
    }
    let current = groups[index]
    let updated = { ..current, matched: current.matched + 1, }
    let final_group = match resolve(value, number_parts) {
      Some(Number(number, ..)) if finite_number(number) =>
        match add_group_number(updated, number, line_number) {
          Ok(summary) => summary
          Err(problem) => return Err(problem)
        }
      Some(Number(_, ..)) =>
        return Err(error(line_number, "number is not finite"))
      Some(_) =>
        return Err(error(line_number, "numeric field must be a number"))
      None => updated
    }
    groups[index] = final_group
  }
  Ok(groups)
}

///|
pub fn group_jsonl(
  input : String,
  group_path : String,
  numeric_path : String,
) -> Result[Array[GroupSummary], LogError] {
  group_lines(
    input.split("\n").map(line => line.to_owned()),
    group_path,
    numeric_path,
  )
}

///|
fn add_group_number(
  group : GroupSummary,
  number : Double,
  line : Int,
) -> Result[GroupSummary, LogError] {
  let next_sum = group.sum + number
  if !finite_number(next_sum) {
    return Err(error(line, "numeric sum is not finite"))
  }
  let next_min = match group.min {
    Some(old) => Some(if number < old { number } else { old })
    None => Some(number)
  }
  let next_max = match group.max {
    Some(old) => Some(if number > old { number } else { old })
    None => Some(number)
  }
  let next_count = group.count + 1
  let next_average = next_sum / next_count.to_double()
  if !finite_number(next_average) {
    return Err(error(line, "numeric average is not finite"))
  }
  Ok({
    ..group,
    count: next_count,
    sum: next_sum,
    min: next_min,
    max: next_max,
    average: Some(next_average),
  })
}
