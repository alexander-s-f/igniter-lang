module Proof.EffectSurface.Affects

pure contract PureWithAffects {
  affects external Somewhere.Else
}

observed contract ObservedWithAffects {
  affects external Somewhere.Else
}

effect contract DuplicateAffects {
  capability net: IO.NetworkCapability
  effect send using net
  affects external A.B
  affects internal C.D
}
