module Budget.Loop.Clean

type Option {
  score: Integer
}

pure contract Searcher {
  input candidates: Collection[Option]
  compute best = 0
  output best: Integer
  loop SearchLoop candidate in candidates max_steps: 500 {
  }
}
