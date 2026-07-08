module Recursion.Clean

-- P47: dotted-path decreases (items.remaining) is a PROP-041 T2 structural-size
-- relation; it requires this module-level size_relation, else OOF-R8.
size_relation Collection remaining

recursive contract SumList {
  input items: Collection[Integer]
  input acc: Integer
  compute total = acc
  output total: Integer
  decreases items.remaining
}
