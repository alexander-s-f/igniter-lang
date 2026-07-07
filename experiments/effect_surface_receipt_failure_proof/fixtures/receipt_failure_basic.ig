module Proof.EffectSurface.ReceiptFailure

type ChargeReceipt {
  charge_id: Text,
  amount: Decimal[2]
}

type PaymentFailure {
  reason: Text
}

effect contract ChargeCard {
  capability payments: IO.NetworkCapability
  effect charge using payments
  receipt ChargeReceipt
  failure PaymentFailure
}
