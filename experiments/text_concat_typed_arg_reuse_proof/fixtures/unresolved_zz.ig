module TextConcatReuseUnresolvedZz
intent "regression control: unresolved ref zz, otherwise identical to unresolved_l.ig"

pure contract W {
  input n : Integer
  compute line : Text = "x${zz}"
  output line : Text
}
