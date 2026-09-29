-- REVIEW probe p08d_invoke_hole_map_into_integer.ig: invoke argument boundary (R17) under R22
module R22Review.Inv
type A { id : Integer }
observed contract Callee {
  input n : Integer
  capability io_db_read : IO.Capability
  effect read_file using io_db_read
  compute done : Integer = 1
  output done : Integer
}
observed contract O {
  input seed : Integer
  input flag : Bool
  input xs : Collection[Integer]
  input m : Map[String, Integer]
  capability io_db_read : IO.Capability
  effect read_file using io_db_read
  invoke recovered = Callee(map_empty()) using io_db_read
  compute page : Integer = recovered
  output page : Integer
}
