-- REVIEW probe p05: map_put / map_get on a Tier-2 (dynamic callee) call_contract result (the UNTYPED residual)
module R22Review.P05
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
  compute m2 = map_put(r, "k", 1)
  compute o : Integer = seed
  output o : Integer
}
