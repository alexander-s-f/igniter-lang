-- REVIEW-1-RECHECK3 probe s07_text_into_variant_field
module R22Recheck3.S
variant V {
  Box { s : String }
}
def f(s: String) -> Integer {
  1
}
contract Callee {
  input s : String
  compute r = 1
  output r : Integer
}
pure contract O {
  input seed : Integer
  input cfg : Map[String, Unknown]
  input t : Text
  input s : String
  input b : Bool
  input xs : Collection[Integer]
  input name : String
  compute a = Box { s: "a" ++ t }
  compute o : Integer = seed
  output o : Integer
}
