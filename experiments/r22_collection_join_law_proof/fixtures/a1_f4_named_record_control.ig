module R22A1.F4ab
type Point { x : Integer, y : Integer }
variant M {
  Raw { n : Integer }
  Off {}
}
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input fs : Collection[Float]
  input cfg : Map[String, Unknown]
  input opens : Collection[Unknown]
  input sm : Map[String, Integer]
  input name : String
  compute pt : Point = { x: seed, y: 2 }
  compute c = count(pt.xs)
  compute o : Integer = seed
  output o : Integer
}
