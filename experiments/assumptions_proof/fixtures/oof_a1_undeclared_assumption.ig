module Risk.Scoring

contract BadAssumptionUse {
  input signal: Signal
  uses assumptions undeclared_heuristic
  compute score = 1
  output score: Integer
}
