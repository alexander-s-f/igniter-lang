-- LANG-CALLABLE-COMPATIBILITY-AND-BINDER-PROOF-REPAIR-R12 specimen r12_empty_fold_returns_element (review F-07 shape CE11)
-- DECLARED ASYMMETRY: an empty fold that returns its bound-but-unknown element, referenced by a later compute.
-- Canon (candidate) admits and returns ordinary 6 (the empty fold returns its seed n = 5; first + 1); Rust refuses OOF-COL4 (lambda return type Unknown does not match accumulator type Integer) on every leg; pristine Canon refused OOF-P1.
module R12.EmptyFoldElement

pure contract F {
  input n : Integer

  compute first : Integer = fold([], n, (a, v) -> v)
  compute total : Integer = first + 1

  output total : Integer
}
