-- RV12G (reviewer): ordinary counterpart of RV12GS. Honored: 3; leaked: 2.
module RV.RV12G

pure contract OrdinaryFold {
  input xs : Collection[Float]

  compute total : Integer = fold(xs, 0, (acc, r) -> {
      let r = r + 10.0
      if r > 10.5 { acc + 1 } else { acc }
    })

  output total : Integer
}
