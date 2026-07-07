module Proof.EffectSurface.Authority

effect contract ChargeCard {
  capability payments: IO.NetworkCapability
  effect charge using payments
  authority billing_operator
}
