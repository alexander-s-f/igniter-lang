-- recheck3 u13 (LEGAL? over-refusal probe): a TYPE spelled __seq__ used as a type parameter — not a value binder.
-- xs=[{v:1},{v:2}] -> 3
module RC3.U13

type __seq__ { v : Integer }

pure contract O {
  input xs : Collection[__seq__]
  compute total : Integer = fold(xs, 0, (acc, r) -> acc + r.v)
  output total : Integer
}
