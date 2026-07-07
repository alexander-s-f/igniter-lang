module Proof.EffectSurface.ReceiptFailure

effect contract ScalarReceipt {
  capability net: IO.NetworkCapability
  effect ping using net
  receipt Text
  failure Text
}
