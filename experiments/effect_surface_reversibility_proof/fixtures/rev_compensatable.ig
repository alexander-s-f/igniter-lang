module Proof.EffectSurface.Reversibility

effect contract ChargeCard {
  capability payments : IO.NetworkCapability
  effect charge using payments
  reversibility :compensatable
  compensation RefundCustomer
}

effect contract RefundCustomer {
  capability payments2 : IO.NetworkCapability
  effect refund using payments2
}
