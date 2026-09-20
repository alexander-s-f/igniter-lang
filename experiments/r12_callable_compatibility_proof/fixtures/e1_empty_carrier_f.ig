-- LANG-CALLABLE-LEXICAL-TYPE-EVIDENCE-READINESS-R11 specimen e1_empty_carrier_f (ordinary only)
-- INSUFFICIENT evidence, declared before runs: the nested carrier is the empty literal [], so v has no element evidence on either frontend.
-- Both keep the ordinary permissive integer-named identity; the body never executes; result 0 (seed). Recorded as unresolved evidence, not a claim.
module R11.E1F

pure contract OrdinaryFold {
  input xs : Collection[Float]

  compute total : Integer = fold(xs, 0, (acc, r) -> acc + fold([], 0, (a, v) -> if v > 10.5 { a + 1 } else { a }))

  output total : Integer
}

