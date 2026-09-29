module Curator.R22
pure contract Test {
  input name : String
  input xs : Collection[Integer]
  compute unknown_result = call_contract(name, xs)
  compute inferred = concat(unknown_result, [1])
  compute result = 1
  output result : Integer
}
