module MathSurface15
-- N0 scalar
pure contract AbsI  { compute x : Integer = 0 - 5 compute r : Integer = abs(x) output r : Integer }
pure contract AbsF  { compute x : Float = 0.0 - 2.5 compute r : Float = abs(x) output r : Float }
pure contract MinI  { compute r : Integer = min(3, 7) output r : Integer }
pure contract MaxF  { compute a : Float = 1.5 compute b : Float = 2.5 compute r : Float = max(a, b) output r : Float }
pure contract ClampI { compute r : Integer = clamp(9, 1, 5) output r : Integer }
pure contract SignF { compute x : Float = 0.0 - 2.5 compute r : Integer = sign(x) output r : Integer }
-- F1 fast
pure contract SinF  { compute x : Float = 0.5 compute r : Float = sin(x) output r : Float }
pure contract CosF  { compute x : Float = 0.5 compute r : Float = cos(x) output r : Float }
pure contract SqrtF { compute x : Float = 4.0 compute r : Float = sqrt(x) output r : Float }
pure contract PiF   { compute r : Float = pi() output r : Float }
-- D1 deterministic
pure contract DSin  { compute x : Float = 0.5 compute r : Float = det_sin(x) output r : Float }
pure contract DCos  { compute x : Float = 0.5 compute r : Float = det_cos(x) output r : Float }
pure contract DSqrt { compute x : Float = 4.0 compute r : Float = det_sqrt(x) output r : Float }
pure contract DLn   { compute x : Float = 2.0 compute r : Float = det_ln(x) output r : Float }
pure contract DExp  { compute x : Float = 1.0 compute r : Float = det_exp(x) output r : Float }
pure contract DTan  { compute x : Float = 0.5 compute r : Float = det_tan(x) output r : Float }
