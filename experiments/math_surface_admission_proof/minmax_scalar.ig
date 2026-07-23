module MinMaxScalar
pure contract ScalarMin { compute r : Integer = min(7, 3) output r : Integer }
pure contract ScalarMax { compute a : Float = 1.5 compute b : Float = 2.5 compute r : Float = max(a, b) output r : Float }
