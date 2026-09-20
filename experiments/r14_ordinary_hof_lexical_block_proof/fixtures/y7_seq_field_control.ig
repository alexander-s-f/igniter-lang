-- reviewer s08 (Rust surface): a user record field / match binding spelled __seq__ read after a bare statement in the arm block.
-- v = Ok{ value: 7 } with a wrapper type field named __seq__ is not expressible for Result; use a user variant.
module RVW.S08

def twice(a: Integer) -> Integer {
  a * 2
}

type Box { __seq__ : Integer }

pure contract O {
  input flag : Bool
  input b : Box

  compute total : Integer = if flag {
      twice(1)
      b.__seq__ + 1
    } else { 0 }

  output total : Integer
}
