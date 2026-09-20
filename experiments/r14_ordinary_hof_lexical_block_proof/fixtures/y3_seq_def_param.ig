-- reviewer s04: a DEF PARAMETER spelled __seq__ ; def-body branch has a bare statement (newly carried by R14).
-- f(7): lawful 7 ; smuggled: twice(1) = 2.   fold over [7, 9] lawful = 16 ; smuggled = 4
module RVW.S04

def twice(a: Integer) -> Integer {
  a * 2
}

def f(__seq__: Integer) -> Integer {
  if __seq__ > 0 {
    twice(1)
    __seq__
  } else {
    0
  }
}

pure contract O {
  input xs : Collection[Integer]

  compute total : Integer = fold(xs, 0, (acc, r) -> acc + f(r))

  output total : Integer
}
