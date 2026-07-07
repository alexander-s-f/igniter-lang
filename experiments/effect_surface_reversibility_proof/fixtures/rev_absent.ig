module Proof.EffectSurface.Reversibility

effect contract NoScale {
  capability net : IO.NetworkCapability
  effect ping using net
}
