module Proof.EffectSurface.Authority

pure contract PureWithAuthority {
  authority somebody
}

observed contract ObservedWithAuthority {
  authority somebody
}

effect contract DuplicateAuthority {
  capability net: IO.NetworkCapability
  effect send using net
  authority first_role
  authority second_role
}
