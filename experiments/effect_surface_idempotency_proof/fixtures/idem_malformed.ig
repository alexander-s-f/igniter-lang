module Proof.EffectSurface.Idempotency

effect contract MalformedIdem {
  capability net: IO.NetworkCapability
  effect send using net
  idempotency whenever
}
