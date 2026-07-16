module Risk.Scoring

assumptions {
  assumption calibration_prior {
    kind :calibrated
    statement "The scoring threshold was calibrated from the prior model card."
    strength 0.82
    source "model-card://risk-scoring/v1"
  }
}

contract PureEpistemicScore {
  input signal: Signal
  uses assumptions calibration_prior
  compute score = calibration_prior.statement
  output score: String
}
