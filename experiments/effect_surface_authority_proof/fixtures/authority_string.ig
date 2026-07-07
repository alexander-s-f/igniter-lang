module Proof.EffectSurface.Authority

effect contract StringAuthority {
  capability net: IO.NetworkCapability
  effect send using net
  authority "billing_operator"
}
