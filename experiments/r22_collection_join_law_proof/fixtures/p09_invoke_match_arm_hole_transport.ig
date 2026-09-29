-- REVIEW probe p09: an invoke argument whose typed annotation tree carries a hole-typed match arm (the typed
-- argument transport is a JSON STRING in the typed program options; deep erasure does not parse strings)
module R22Review.P09
variant Mode {
  Raw { n : Integer }
  Off {}
}
observed contract Callee {
  input ys : Collection[Collection[Integer]]
  capability io_db_read : IO.Capability
  effect read_file using io_db_read
  compute done : Integer = 1
  output done : Integer
}
observed contract O {
  input seed : Integer
  input mode : Mode
  capability io_db_read : IO.Capability
  effect read_file using io_db_read
  invoke recovered = Callee(match mode {
    Raw { n } => []
    Off {} => [[1]]
  }) using io_db_read
  compute page : Integer = recovered
  output page : Integer
}
