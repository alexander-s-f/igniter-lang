module Proof.EffectSurface.Idempotency

type SendReceipt {
  note: Text
}

effect contract SendOrder {
  input order_id: Text

  capability net: IO.NetworkCapability
  effect send using net
  receipt SendReceipt
  idempotency key order_id
}
