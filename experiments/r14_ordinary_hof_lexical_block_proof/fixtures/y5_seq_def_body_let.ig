-- reviewer s07: a def-body `let __seq__` followed by a bare statement (def bodies lowered this way BEFORE R14 too).
-- f(7): let __seq__ = 70 ; twice(1) ; __seq__  -> lawful 70 ; smuggled 2.   fold [7,9] -> lawful 70+90=160 ; smuggled 4
module RVW.S07

def twice(a: Integer) -> Integer {
  a * 2
}

def f(a: Integer) -> Integer {
  let __seq__ = a * 10
  twice(1)
  __seq__
}

pure contract O {
  input xs : Collection[Integer]

  compute total : Integer = fold(xs, 0, (acc, r) -> acc + f(r))

  output total : Integer
}
