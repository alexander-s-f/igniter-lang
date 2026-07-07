module Proof.EffectSurface.Affects

effect contract MalformedAffects {
  capability net: IO.NetworkCapability
  effect send using net
  affects sideways Foo.Bar
}
