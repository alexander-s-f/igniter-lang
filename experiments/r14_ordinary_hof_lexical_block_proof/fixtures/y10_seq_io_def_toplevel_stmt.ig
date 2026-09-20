-- recheck q01c: IO-reaching def, NO if: a top-level bare IO statement then the PARAMETER __seq__ is returned.
-- lawful: the parameter text ; lowered: let __seq__ = <IO result> in ref __seq__  -> returns the IO Result
module RCK.Q01C

def log_then(__seq__: Text, io_write: IO.Capability) -> Text {
  stdlib.IO.write_text("p.log", "b", io_write)
  __seq__
}

observed contract O {
  capability io_write: IO.Capability
  effect write_file using io_write
  input path : Text

  compute r : Text = log_then(path, io_write)

  output r : Text
}
