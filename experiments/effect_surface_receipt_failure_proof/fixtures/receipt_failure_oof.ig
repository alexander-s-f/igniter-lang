module Proof.EffectSurface.ReceiptFailure

type SomeReceipt {
  note: Text
}

pure contract PureWithReceipt {
  receipt SomeReceipt
}

effect contract DuplicateReceipt {
  capability net: IO.NetworkCapability
  effect send using net
  receipt SomeReceipt
  receipt SomeReceipt
}

effect contract UnknownFailureType {
  capability net2: IO.NetworkCapability
  effect send2 using net2
  failure NoSuchType
}
