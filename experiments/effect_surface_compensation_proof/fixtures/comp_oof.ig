module Proof.EffectSurface.Compensation

pure contract PureWithComp {
  compensation Somewhere
}

observed contract ObservedWithWaiver {
  no_compensation
}

effect contract DoubleComp {
  capability net : IO.NetworkCapability
  effect send using net
  compensation A
  compensation B
}

effect contract BothForms {
  capability net2 : IO.NetworkCapability
  effect send2 using net2
  compensation A
  no_compensation
}

effect contract UnknownRef {
  capability net3 : IO.NetworkCapability
  effect send3 using net3
  compensation NoSuchContract
}

pure contract A {
  input x : Integer
  compute y = x
  output y : Integer
}

pure contract B {
  input x : Integer
  compute y = x
  output y : Integer
}

pure contract Somewhere {
  input x : Integer
  compute y = x
  output y : Integer
}
