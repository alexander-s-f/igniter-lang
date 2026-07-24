module Risk.Scoring

type Signal {
  value: Integer
}

assumptions {
  assumption homophily {
    kind :heuristic
    statement "People with similar beliefs interact more often."
    strength 0.7
  }
}

observed contract ScoreInteraction {
  input a: Signal
  input b: Signal
  uses assumptions homophily
  escape profile_source
  compute score = homophily.statement
  output score: String evidence [a, b, homophily]
}
