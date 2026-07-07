module Proof.EffectSurface.Idempotency

effect contract FireOnce {
  capability net: IO.NetworkCapability
  effect fire using net
  idempotency none
}
