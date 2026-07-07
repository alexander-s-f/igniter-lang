module Proof.EffectSurface.Authority

effect contract DottedAuthority {
  capability net: IO.NetworkCapability
  effect send using net
  authority Billing.Operator
}
