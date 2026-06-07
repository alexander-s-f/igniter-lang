module Proof.ViaProfile.Basic

effect contract ChargeCustomer via payments_profile {
  capability charge_cap: IO.NetworkCapability
  effect charge using charge_cap
}
