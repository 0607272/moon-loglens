///|
extern "js" fn read_input_ffi(path : String) -> String =
  #| function(path) {
  #|   const fs = require("fs");
  #|   try {
  #|     return fs.readFileSync(path === "-" ? 0 : path, "utf8");
  #|   } catch (error) {
  #|     return "__MOON_LOGLENS_ERROR__:" + String(error);
  #|   }
  #| }

///|
extern "js" fn write_stderr(message : String) -> Unit =
  #| function(message) {
  #|   process.stderr.write(message + "\n");
  #| }

///|
extern "js" fn set_exit_code(code : Int) -> Unit =
  #| function(code) {
  #|   process.exitCode = code;
  #| }

///|
fn read_input(path : String) -> Result[String, String] {
  let content = read_input_ffi(path)
  let marker = "__MOON_LOGLENS_ERROR__:"
  if content.has_prefix(marker) {
    Err(content[marker.length():].to_owned())
  } else {
    Ok(content)
  }
}
