module Proof.EffectSurface.Compensation

effect contract ChargeCard {
  capability payments : IO.NetworkCapability
  effect charge using payments
  compensation RefundCustomer
}

effect contract RefundCustomer {
  capability payments2 : IO.NetworkCapability
  effect refund using payments2
}
