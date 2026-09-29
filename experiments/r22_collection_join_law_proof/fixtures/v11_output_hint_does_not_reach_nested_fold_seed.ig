-- R22 witness (REVIEW-1-VERIFY V3 class): a node-keyed output hint must not name a literal nested in a fold seed
module R12.G4H

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

  compute totals: Tot =
    fold_stream(readings, { total: 0.0 }, (acc, r) -> fold([r], { total: acc.total }, (a, v) -> if v > a.total { { total: a.total + v } } else { a })) @window_bounded

  output totals: Tot
}
