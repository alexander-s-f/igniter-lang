-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen v1_branch_shadow_input
-- BYTECODE path (contract-level if): the then-branch let shadows the INPUT base; the else branch reads the outer base. base=7: flag=true -> 101; flag=false -> 7.
module R14.V1

pure contract O {
  input flag : Bool
  input base : Integer

  compute total : Integer = if flag { let base = 100
      base + 1 } else { base }

  output total : Integer
}
