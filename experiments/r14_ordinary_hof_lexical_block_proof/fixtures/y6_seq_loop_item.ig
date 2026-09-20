module R14.Pilot.LoopItem

pure contract O {
  input xs : Collection[Integer]

  loop Accumulate __seq__ in xs max_steps: 10 {
    lead total: Integer = 0
    compute total = total + __seq__
  }

  output xs : Collection[Integer]
}
