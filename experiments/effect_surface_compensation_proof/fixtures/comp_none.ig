module Proof.EffectSurface.Compensation

irreversible contract SendEmail {
  capability mailer : IO.NetworkCapability
  effect send using mailer
  no_compensation
}
