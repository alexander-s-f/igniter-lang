module Proof.EffectSurface.Compensation

effect contract PingOnly {
  capability net : IO.NetworkCapability
  effect ping using net
}
