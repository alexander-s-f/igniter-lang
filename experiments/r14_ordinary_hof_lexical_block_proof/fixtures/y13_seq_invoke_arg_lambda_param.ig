module R14.Audit.A1
def twice(a: Integer) -> Integer {
  a * 2
}

observed contract RecoverDb {
  input seed: Integer
  capability io_db_read: IO.Capability
  effect read_file using io_db_read
  compute rows = seed
  output rows: Integer
}
observed contract CheckpointDb {
  input xs: Collection[Integer]
  capability io_db_read: IO.Capability
  effect read_file using io_db_read
  invoke recovered = RecoverDb(fold(xs, 0, (a, __seq__) -> {
      twice(__seq__)
      a + __seq__
    })) using io_db_read
  compute page = recovered
  output page: Integer
}
