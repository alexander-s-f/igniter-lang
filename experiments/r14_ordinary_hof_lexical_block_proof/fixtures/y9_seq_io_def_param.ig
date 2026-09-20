-- recheck q01: an IO-REACHING def (both frontends skip typecheck_function_body for it) whose PARAMETER is `__seq__`.
-- The executed branch has a PURE bare statement then reads the parameter. lawful: "ab" ; smuggled: "abab"
module RCK.Q01

def dbl(t: Text) -> Text {
  concat(t, t)
}

def log_then(__seq__: Text, io_write: IO.Capability) -> Text {
  if __seq__ == "never" {
    stdlib.IO.write_text("p.log", "b", io_write)
    "io"
  } else {
    dbl(__seq__)
    __seq__
  }
}

observed contract O {
  capability io_write: IO.Capability
  effect write_file using io_write
  input path : Text

  compute r : Text = log_then(path, io_write)

  output r : Text
}
