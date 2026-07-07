module Proof.EffectSurface.Authority

effect contract NoAuthority {
  capability net: IO.NetworkCapability
  effect send using net
}
