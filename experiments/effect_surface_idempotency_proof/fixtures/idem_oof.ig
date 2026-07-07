module Proof.EffectSurface.Idempotency

pure contract PureWithIdem {
  idempotency natural
}

observed contract ObservedWithIdem {
  idempotency natural
}

effect contract DuplicateIdem {
  capability net: IO.NetworkCapability
  effect send using net
  idempotency natural
  idempotency none
}

effect contract UnknownKeyRef {
  capability net2: IO.NetworkCapability
  effect send2 using net2
  idempotency key missing_symbol
}
