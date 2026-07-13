-- monadic_extension.ig
-- Conformance fixture verifying Option[T] and Result[T, E] monadic operations.

module SparkCRM.Monadic
-- LANG-CONTRACT-SINGLE-OUTPUT-LAW-P2: named result record (one value per contract)
type OptionWorkflowResult { is_some_val : Bool, is_none_val : Bool, mapped : Option[Integer], flat_mapped : Option[Integer], unwrapped : Integer, unwrapped_mapped : Integer }

-- LANG-CONTRACT-SINGLE-OUTPUT-LAW-P2: named result record (one value per contract)
type ResultWorkflowResult { is_ok_val : Bool, is_err_val : Bool, mapped : Result[Integer, String], flat_mapped : Result[Integer, String], unwrapped_or_val : Integer }


contract OptionWorkflow {
  input opt_in: Option[Integer]
  input fallback: Integer

  compute is_some_val = is_some(opt_in)
  compute is_none_val = is_none(opt_in)
  compute mapped = map(opt_in, x -> x * 2)
  compute flat_mapped = flat_map(opt_in, x -> some(x + 10))
  compute unwrapped = unwrap_or(opt_in, fallback)
  compute unwrapped_mapped = unwrap_or(map(opt_in, x -> x * 3), fallback)

  compute result : OptionWorkflowResult = { is_some_val: is_some_val, is_none_val: is_none_val, mapped: mapped, flat_mapped: flat_mapped, unwrapped: unwrapped, unwrapped_mapped: unwrapped_mapped }

  output result : OptionWorkflowResult
}

contract ResultWorkflow {
  input res_in: Result[Integer, String]
  input fallback: Integer

  compute is_ok_val = is_ok(res_in)
  compute is_err_val = is_err(res_in)
  compute mapped = map(res_in, x -> x * 5)
  compute flat_mapped = and_then(res_in, x -> ok(x + 100))
  compute unwrapped_or_val = unwrap_or(res_in, fallback)

  compute result : ResultWorkflowResult = { is_ok_val: is_ok_val, is_err_val: is_err_val, mapped: mapped, flat_mapped: flat_mapped, unwrapped_or_val: unwrapped_or_val }

  output result : ResultWorkflowResult
}

contract ResultUnwrap {
  input res_in: Result[Integer, String]
  compute val = unwrap(res_in)
  output val: Integer
}
