module Proof.EffectSurface.Reversibility

effect contract V1 {
  capability c1 : IO.NetworkCapability
  effect e1 using c1
  reversibility :reversible
}

effect contract V2 {
  capability c2 : IO.NetworkCapability
  effect e2 using c2
  reversibility :refundable
}

effect contract V3 {
  capability c3 : IO.NetworkCapability
  effect e3 using c3
  reversibility :append_only
}

irreversible contract V4 {
  capability c4 : IO.NetworkCapability
  effect e4 using c4
  reversibility :irreversible
  no_compensation
}

irreversible contract V5 {
  capability c5 : IO.NetworkCapability
  effect e5 using c5
  reversibility :destructive
  no_compensation
}
