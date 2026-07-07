module Proof.EffectSurface.Reversibility

irreversible contract CapableButWaived {
  capability net : IO.NetworkCapability
  effect send using net
  reversibility :compensatable
  no_compensation
}
