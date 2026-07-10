module Proof.NetworkCapability.Grammar

effect contract SendPing {
  capability net: IO.NetworkCapability
  effect send using net
}
