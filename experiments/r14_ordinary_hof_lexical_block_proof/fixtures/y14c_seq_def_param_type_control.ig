-- recheck3 u13c: a DEF parameter whose TYPE is Collection[__seq__] (parameter NAME is ordinary). xs=[{v:1},{v:2}] -> 3
module RC3.U13C

type __seq__ { v : Integer }

def total_of(items: Collection[__seq__]) -> Integer {
  fold(items, 0, (acc, r) -> acc + r.v)
}

pure contract O {
  input n : Integer
  compute total : Integer = n + 1
  output total : Integer
}
