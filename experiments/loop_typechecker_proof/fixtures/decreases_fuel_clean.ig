module Fuel.Decreases.Clean

recursive contract FactorialFuel {
  input n: Integer
  input acc: Integer
  compute result = acc
  output result: Integer
  decreases fuel
  max_steps 100
}
