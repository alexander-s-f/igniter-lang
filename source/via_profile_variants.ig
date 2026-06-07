module Proof.ViaProfile.Variants

pure contract ScoreRisk {
  input score: Integer
  compute result = score
  output result: Integer
}

observed contract ReadSensor via telemetry_profile {
  input sensor_id: String
  escape sensor_read
  output sensor_id: String
}

privileged contract UnlockDoor via security_profile {
  capability door_cap: IO.NetworkCapability
  effect unlock using door_cap
}

irreversible contract ArchiveRecord via archive_profile {
  capability archive_cap: IO.NetworkCapability
  effect archive using archive_cap
}
