-- recheck q11: IO-reaching def whose body has a LAMBDA parameter spelled __seq__ read after a bare statement in the
-- lambda block (same root cause as q01: the def body is never scanned). lawful per element: x ; smuggled: dbl(x)
module RCK.Q11

def dbl(t: Integer) -> Integer {
  t * 2
}

def sum_then_log(xs: Collection[Integer], io_write: IO.Capability) -> Integer {
  if count(xs) == 0 {
    stdlib.IO.write_text("p.log", "empty", io_write)
    0
  } else {
    fold(xs, 0, (acc, __seq__) -> {
      dbl(__seq__)
      acc + __seq__
    })
  }
}

observed contract O {
  capability io_write: IO.Capability
  effect write_file using io_write
  input xs : Collection[Integer]

  compute r : Integer = sum_then_log(xs, io_write)

  output r : Integer
}
