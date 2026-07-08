module Recursion.Missing

recursive contract SumBroken {
  input items: Collection[Integer]
  input acc: Integer
  compute total = acc
  output total: Integer
}
