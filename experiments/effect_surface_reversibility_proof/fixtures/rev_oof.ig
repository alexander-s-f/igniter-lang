module Proof.EffectSurface.Reversibility

pure contract PureWithScale {
  reversibility :reversible
}

observed contract ObservedWithScale {
  reversibility :reversible
}

effect contract DoubleScale {
  capability net : IO.NetworkCapability
  effect send using net
  reversibility :reversible
  reversibility :compensatable
}

effect contract Contradiction {
  capability net2 : IO.NetworkCapability
  effect send2 using net2
  reversibility :irreversible
  compensation SomeComp
}

effect contract SomeComp {
  capability net3 : IO.NetworkCapability
  effect send3 using net3
}
