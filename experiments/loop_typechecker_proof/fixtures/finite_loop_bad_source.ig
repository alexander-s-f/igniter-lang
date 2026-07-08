module Loop.TypeChecker.BadSource

pure contract BadProcessor {
  input limit: Integer
  compute result = limit
  output result: Integer
  for LimitLoop item in limit {
  }
}
