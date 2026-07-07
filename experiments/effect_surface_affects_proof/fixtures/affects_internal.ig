module Proof.EffectSurface.Affects

effect contract WriteLedger {
  affects internal Ledger.WriteModel
}
