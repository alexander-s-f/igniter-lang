module R14.Pilot.MatchBinding2

def twice(a: Integer) -> Integer {
  a * 2
}

variant Boxed {
  Full { __seq__ : Integer }
  Empty {}
}

pure contract O {
  input b : Boxed
  input xs : Collection[Integer]

  compute total : Integer = match b {
    Full { __seq__ } => fold(xs, 0, (acc, r) -> {
        twice(r)
        acc + __seq__
      })
    Empty {} => 0
  }

  output total : Integer
}
