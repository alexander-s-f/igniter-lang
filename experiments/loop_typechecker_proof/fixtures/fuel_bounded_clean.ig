module Fuel.Clean

fuel_bounded contract SearchOptimal {
  input n: Integer
  compute result = n
  output result: Integer
  max_steps 1000
}
