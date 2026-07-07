module Proof.EffectSurface.Compensation

effect contract DottedRef {
  capability net : IO.NetworkCapability
  effect send using net
  compensation Billing.Refund
}
