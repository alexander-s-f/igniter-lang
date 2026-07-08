module Loop.TypeChecker.Clean

type Claim {
  amount: Integer
}

pure contract ClaimProcessor {
  input claims: Collection[Claim]
  compute count = 0
  output count: Integer
  for ClaimLoop claim in claims {
  }
}
