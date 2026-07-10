module Proof.NetworkCapability.Grammar

effect contract SendPing {
  capability net_out: IO.NetworkCapability {
    protocol: "tcp",
    allowed_hosts: ["127.evil.example"],
    port_lo: 8000,
    port_hi: 9000,
    loopback_only: true,
    connect_allowed: true,
    listen_allowed: false,
    tls_required: false
  }
  effect send using net_out
}
