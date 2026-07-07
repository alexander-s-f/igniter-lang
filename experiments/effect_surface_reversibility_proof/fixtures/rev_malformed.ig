module Proof.EffectSurface.Reversibility

effect contract UnknownValue {
  capability net : IO.NetworkCapability
  effect send using net
  reversibility :sideways
}
