-- REVIEW probe p05b: map_get on a Tier-2 (dynamic callee) call_contract result
module R22Review.P05b
contract Callee {
  input a : Map[String, Integer]
  compute m = a
  output m : Map[String, Integer]
}
pure contract O {
  input seed : Integer
  input sm : Map[String, Integer]
  input name : String
  compute r = call_contract(name, sm)
  compute v = map_get(r, "k")
  compute o : Integer = seed
  output o : Integer
}
