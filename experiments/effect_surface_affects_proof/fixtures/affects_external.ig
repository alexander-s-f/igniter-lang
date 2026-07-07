module Proof.EffectSurface.Affects

effect contract ChargeCard {
  capability payments: IO.NetworkCapability
  effect charge using payments
  affects external PaymentGateway.ChargeEndpoint
}
