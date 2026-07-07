module Proof.EffectSurface.Affects

effect contract Defaulted {
  capability net: IO.NetworkCapability
  effect send using net
}
