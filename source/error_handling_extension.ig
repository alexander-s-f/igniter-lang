-- error_handling_extension.ig
-- Conformance fixture for Direction F: try_catch, propagate, validate

module SparkCRM.ErrorHandling
-- LANG-CONTRACT-SINGLE-OUTPUT-LAW-P2: named result record (one value per contract)
type ErrorHandlingWorkflowResult { recovered : Integer, ok_passthrough : Integer, propagated : Integer, validated : Result[Integer, String], invalid : Result[Integer, String] }


contract ErrorHandlingWorkflow {
  -- Inputs
  input res_ok:  Result[Integer, String]   -- e.g. {ok: 42}
  input res_err: Result[Integer, String]   -- e.g. {err: "oops"}
  input raw_val: Integer                   -- e.g. 7
  input threshold: Integer                 -- e.g. 5

  -- try_catch: recover from err branch with a constant fallback lambda
  compute recovered = try_catch(res_err, e -> 0)

  -- try_catch on ok: handler is never called, inner value passes through
  compute ok_passthrough = try_catch(res_ok, e -> 0)

  -- propagate: extract ok value from a successful result
  compute propagated = propagate(res_ok)

  -- validate: raw_val > threshold → ok(raw_val), else err("too_small")
  compute validated = validate(raw_val, v -> v > threshold, "too_small")

  -- validate a failing case: 3 > 5 is false → err("too_small")
  compute invalid = validate(3, v -> v > threshold, "too_small")

  compute result : ErrorHandlingWorkflowResult = { recovered: recovered, ok_passthrough: ok_passthrough, propagated: propagated, validated: validated, invalid: invalid }

  output result : ErrorHandlingWorkflowResult
}
