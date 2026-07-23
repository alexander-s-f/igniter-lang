module MinMaxAggregate
-- The collection-aggregate reading (stdlib.Collections, collections.ig:20-21).
-- Rust compiles and runs it; Ruby canon has no aggregate arm and refuses.
type AggPoint { v : Float }
pure contract AggSpan {
  compute xs : Collection[AggPoint] = [ { v: 1.5 }, { v: 0.0 - 2.5 }, { v: 0.5 } ]
  compute lo : Float = unwrap_or(min(xs, :v), 999.0)
  compute hi : Float = unwrap_or(max(xs, :v), 999.0)
  compute span : Float = hi - lo
  output span : Float
}
