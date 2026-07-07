module Proof.EffectSurface.Idempotency

effect contract SetFlag {
  capability store: IO.Capability
  effect set_flag using store
  idempotency natural
}
