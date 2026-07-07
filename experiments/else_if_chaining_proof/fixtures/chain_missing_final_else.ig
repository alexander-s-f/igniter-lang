module Proof.ElseIfChain

contract ChainMissingFinalElse {
  input x: Integer

  compute y = if x == 0 { 10 } else if x == 1 { 20 }

  output y: Integer
}
