module R22A1.E
type Row { amount : Integer, tag : String }
pure contract O {
  input rows : Collection[Row]
  compute kept = filter(rows, r -> r.nope == 1)
  compute total = sum(kept, :missing)
  compute n = count(kept)
  compute o : Integer = n
  output o : Integer
}
