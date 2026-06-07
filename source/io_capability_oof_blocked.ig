module Proof.IOCapability.OofBlocked

pure contract WrongModifier {
  capability bad_cap: IO.NetworkCapability
  effect connect_bad using bad_cap
}

effect contract MissingCap {
  effect orphan using nonexistent_cap
}

effect contract UnboundCap {
  capability unused_cap: IO.NetworkCapability
}
