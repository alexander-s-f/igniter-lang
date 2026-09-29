-- REVIEW-1-RECHECK2 probe z18: String ++ Text (control for z17)
module R22Recheck2.Z18
pure contract O {
  input seed : Integer
  input t : Text
  input name : String
  compute a = name ++ t
  compute o : Integer = seed
  output o : Integer
}
