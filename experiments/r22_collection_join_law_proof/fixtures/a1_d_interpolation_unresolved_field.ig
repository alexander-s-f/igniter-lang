module R22A1.T9
type P { a : String }
pure contract R {
  input p : P
  compute line : Text = "${p.a}${p.zzz}"
  compute more = "x: ${line} ${p.a}"
  compute n = count(line)
  output line : Text
}
