module TextConcatReuseUnresolvedL
intent "regression fixture: unresolved ref literally named l inside an interpolation must refuse OOF-P1 with strict JSON stdout and no DEBUG output"

pure contract W {
  input n : Integer
  compute line : Text = "x${l}"
  output line : Text
}
