-- LANG-CALLABLE-COMPATIBILITY-AND-BINDER-PROOF-REPAIR-R12 specimen r12_unbound_name
-- COUNTER-CONTROL: an UNDECLARED name w inside the nested lambda over the empty carrier: refused OOF-P1 on both B frontends.
module R12.Unbound

observed contract S {
  input device_id: String
  stream readings: Float

  window "r12/{device_id}" {
    kind: :count,
    size: 3,
    on_close: :snapshot
  }
  compute total: Integer =
    fold_stream(readings, 0, (acc, r) -> acc + fold([], 0, (a, v) -> if w > 10.5 { a + 1 } else { a })) @window_bounded

  output total: Integer
}
