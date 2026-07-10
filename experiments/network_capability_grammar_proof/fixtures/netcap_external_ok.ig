module Proof.NetworkCapability.Grammar

effect contract SendPing {
  capability net_out: IO.NetworkCapability {
    protocol: "tcp",
    allowed_hosts: ["api.example.com"],
    port_lo: 443,
    port_hi: 443,
    loopback_only: false,
    connect_allowed: true,
    listen_allowed: false,
    tls_required: true
  }
  effect send using net_out
}
