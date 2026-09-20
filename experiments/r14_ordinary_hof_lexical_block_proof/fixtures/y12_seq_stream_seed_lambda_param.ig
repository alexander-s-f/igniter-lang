-- recheck2 u06: the SEED expression of a fold_stream holds an ordinary fold whose lambda PARAMETER is __seq__ with a
-- bare statement (the fold_stream decl is excluded from the generic expression scan; R10 checks the callable only).
-- seed lawful = 0+1+2 = 3 ; smuggled = (0+2)+(2... ) a + twice(x): 0+2=2, 2+4=6. events [10,20] -> lawful 33 ; smuggled 36
module RC2.U06

def twice(a: Integer) -> Integer {
  a * 2
}

observed contract S {
  input device_id: String
  stream readings: Integer

  window "rc2/{device_id}" {
    kind: :count,
    size: 2,
    on_close: :snapshot
  }

  compute total: Integer =
    fold_stream(readings, fold([1, 2], 0, (a, __seq__) -> {
      twice(__seq__)
      a + __seq__
    }), (acc, r) -> acc + r) @window_bounded

  output total: Integer
}
