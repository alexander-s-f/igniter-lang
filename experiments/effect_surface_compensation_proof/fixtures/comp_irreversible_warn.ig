module Proof.EffectSurface.Compensation

irreversible contract BurnItDown {
  capability fs : IO.FileCapability
  effect burn using fs
}
