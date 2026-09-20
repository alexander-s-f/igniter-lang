-- RV02G (reviewer): ordinary counterpart of RV02GS. Honored: 6.0; leaked outer r: 32.0.
module RV.RV02G

pure contract OrdinaryFold {
  input xs : Collection[Float]

  compute total : Float = fold(xs, 0.0, (acc, r) ->
      if r > 10.5 {
        let r = 3.0
        if r > 2.0 { acc + r } else { acc }
      } else {
        acc
      })

  output total : Float
}
