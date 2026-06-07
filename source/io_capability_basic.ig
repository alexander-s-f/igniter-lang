module Proof.IOCapability.Basic

effect contract ConnectToService {
  capability net_conn: IO.NetworkCapability
  effect connect_to_service using net_conn
}
