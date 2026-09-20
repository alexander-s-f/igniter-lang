-- reviewer s03: a COMPUTE spelled __seq__ read after a bare statement in a lambda branch.
-- xs=[1,2]: __seq__ = 50 ; lawful = (0+50)+(50+50)... : r=1: acc=0 -> twice(1); acc + __seq__ = 50 ; r=2: 50+50 = 100
-- smuggled: acc + twice(r): 0+2=2 ; 2+4=6
module RVW.S03

def twice(a: Integer) -> Integer {
  a * 2
}

pure contract O {
  input xs : Collection[Integer]

  compute __seq__ : Integer = 50
  compute total : Integer = fold(xs, 0, (acc, r) -> if r > 0 {
      twice(r)
      acc + __seq__
    } else { acc })

  output total : Integer
}
