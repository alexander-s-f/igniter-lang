-- reviewer s01: an INPUT spelled __seq__ ; a contract-level branch has a BARE statement then reads the input.
-- Lawful outcomes: refusal (OOF-COL4) or the value 8 (= input 7 + 1). The lowering binds the bare statement to
-- `__seq__`, so a smuggled binder reads twice(1)=2 -> 3.
module RVW.S01

def twice(a: Integer) -> Integer {
  a * 2
}

pure contract O {
  input flag : Bool
  input __seq__ : Integer

  compute total : Integer = if flag {
      twice(1)
      __seq__ + 1
    } else { 0 }

  output total : Integer
}
