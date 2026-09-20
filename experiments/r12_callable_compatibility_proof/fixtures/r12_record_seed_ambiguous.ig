-- LANG-CALLABLE-COMPATIBILITY-AND-BINDER-PROOF-REPAIR-R12 specimen r12_record_seed_ambiguous
-- COUNTER-CONTROL (structural ambiguity, no record hint: the compute is Float): two declared shapes share the field set of the nested seed literal.
-- Refused at admission on both B frontends with each frontend's own rule: Rust OOF-P1 (the seed stays Unknown, so `.total` is an unresolved field: Unknown.total), Canon OOF-TY0 (Ambiguous record literal type).
module R12.RecordSeedAmbiguous

type Tot { total : Float }
type Sum { total : Float }

observed contract S {
  input device_id: String
  stream readings: Float

  window "r12/{device_id}" {
    kind: :count,
    size: 3,
    on_close: :snapshot
  }
  compute total: Float =
    fold_stream(readings, 0.0, (acc, r) -> fold([r], { total: acc }, (a, v) -> if v > a.total { { total: a.total + v } } else { a }).total) @window_bounded

  output total: Float
}
