module MathSurfaceNegatives
pure contract MixedMin { compute a : Integer = 3 compute b : Float = 2.5 compute r : Float = min(a, b) output r : Float }
pure contract BadArity { compute r : Float = sqrt(1.0, 2.0) output r : Float }
pure contract BadType  { compute t : String = "x" compute r : Float = sqrt(t) output r : Float }
