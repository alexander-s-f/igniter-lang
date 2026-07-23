module MinMaxOverload
import stdlib.math

-- Both readings of the overloaded bare names `min`/`max` in ONE program:
-- the scalar Tier-N0 helpers (stdlib.Math, math.ig:41-42) and the collection
-- aggregates (stdlib.Collections, collections.ig:20-21). Disambiguated live by
-- first-argument type.
pure contract MinMaxOverloadProbe {
  input rows : Collection[Row]
  compute agg_lo = min(rows, :value)
  compute probe = min(7, 3)
  output probe : Integer
}

type Row {
  value : Integer
}
