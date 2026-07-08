module Fuel.Decreases.Missing

recursive contract FactorialBroken {
  input n: Integer
  input acc: Integer
  compute result = acc
  output result: Integer
  decreases fuel
}
