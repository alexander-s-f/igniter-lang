-- add_quickstart.ig
-- Experimental quickstart source fixture — S3-R223-C2-I
-- Bounded CORE source equivalent to source/add.ig
-- Authorization: S3-R223-C1-A
-- Scope: compiler-accepted CORE only; not all-grammar support
-- Not: temporal/TBackend, counterfactual, profile-discovery, or public-demo pressure

module Lang.Examples.Add

contract Add {
  input  a: Integer
  input  b: Integer

  compute sum = a + b

  output sum: Integer
}
