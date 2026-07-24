# frozen_string_literal: true

# Internal, direct-require-only evaluator used by canon expression proofs.
#
# LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 removes the predecessor nullable
# `option_construct` owner. The evaluator now exposes one nominal Option value
# and accepts only first-class v1 constructor/match/call identities. It is not
# a public runtime, CLI, or host-codec authority; igniter-vm-core owns those.

module IgniterLang
  class SemanticIRExpressionEvaluator
    Error = Class.new(StandardError)
    MalformedIfExprError = Class.new(Error)
    ConditionNotBoolError = Class.new(Error)
    UnsupportedExpressionKindError = Class.new(Error)
    MissingReferenceError = Class.new(Error)

    class OptionCarrierError < Error
      attr_reader :reason

      def initialize(reason)
        @reason = reason
        super("OOF-VM-OPTION-CARRIER: #{reason}")
      end
    end

    # A nominal in-process proof value. `Some(nil)` remains distinguishable
    # from `None`; neither arm is inferred from the payload or Record keys.
    class OptionValue
      attr_reader :arm, :value

      def self.some(value)
        new(:some, value)
      end

      def self.none
        @none ||= new(:none, nil).freeze
      end

      def initialize(arm, value)
        @arm = arm
        @value = value
        freeze
      end

      def some?
        arm == :some
      end

      def none?
        arm == :none
      end

      def ==(other)
        other.is_a?(OptionValue) &&
          arm == other.arm &&
          (none? || value == other.value)
      end

      alias eql? ==

      def hash
        [self.class, arm, none? ? nil : value].hash
      end

      # Proof/debug rendering is bounded and does not echo payload contents.
      def inspect
        some? ? "#<OptionValue Some(...)>" : "#<OptionValue None>"
      end

      private_class_method :new
    end

    SUPPORTED_KINDS = %w[
      literal
      ref
      if_expr
      array_literal
      record_literal
      option_carrier_guard_v1
      option_value_construct
      option_match
      call
    ].freeze

    OPTION_CALLS = %w[
      or_else
      unwrap_or
      stdlib.option.is_some
      stdlib.option.is_none
      stdlib.option.map
      stdlib.option.flat_map
      stdlib.option.and_then
    ].freeze

    LEGACY_OPTION_CALLS = %w[some none stdlib.option.wrap].freeze
    UNHANDLED = Object.new.freeze

    def evaluate(expr, values = {}, call_trace: nil, external_evaluator: nil)
      if external_evaluator
        eval_expr_ext(expr, values, call_trace, external_evaluator)
      else
        eval_expr(expr, values, call_trace)
      end
    end

    private

    def eval_expr(expr, values, call_trace)
      validate_expression!(expr)
      kind = expr.fetch("kind")
      call_trace&.push(kind)
      option_error!("legacy_constructor_refused") if legacy_option_node?(expr)

      case kind
      when "literal"
        eval_literal(expr)
      when "ref"
        eval_ref(expr, values)
      when "if_expr"
        eval_if_expr(expr, values, call_trace)
      when "array_literal"
        expr.fetch("items", []).map { |item| eval_expr(item, values, call_trace) }
      when "record_literal"
        expr.fetch("fields", {}).transform_values { |item| eval_expr(item, values, call_trace) }
      when "option_carrier_guard_v1"
        eval_option_guard(expr) { |body| eval_expr(body, values, call_trace) }
      when "option_value_construct"
        eval_option_construct_v1(expr) { |value| eval_expr(value, values, call_trace) }
      when "option_match"
        eval_option_match(expr, values) { |body, scope| eval_expr(body, scope, call_trace) }
      when "call"
        result = eval_option_call(expr, values) do |child, scope|
          eval_expr(child, scope, call_trace)
        end
        return result unless result.equal?(UNHANDLED)

        unsupported!(kind, expr.fetch("fn", nil))
      else
        unsupported!(kind)
      end
    end

    def eval_expr_ext(expr, values, call_trace, external_evaluator)
      validate_expression!(expr)
      kind = expr.fetch("kind")
      call_trace&.push(kind)
      option_error!("legacy_constructor_refused") if legacy_option_node?(expr)

      case kind
      when "literal"
        eval_literal(expr)
      when "ref"
        eval_ref(expr, values)
      when "if_expr"
        eval_if_expr_ext(expr, values, call_trace, external_evaluator)
      when "array_literal"
        expr.fetch("items", []).map do |item|
          eval_expr_ext(item, values, call_trace, external_evaluator)
        end
      when "record_literal"
        expr.fetch("fields", {}).transform_values do |item|
          eval_expr_ext(item, values, call_trace, external_evaluator)
        end
      when "option_carrier_guard_v1"
        eval_option_guard(expr) do |body|
          eval_expr_ext(body, values, call_trace, external_evaluator)
        end
      when "option_value_construct"
        eval_option_construct_v1(expr) do |value|
          eval_expr_ext(value, values, call_trace, external_evaluator)
        end
      when "option_match"
        eval_option_match(expr, values) do |body, scope|
          eval_expr_ext(body, scope, call_trace, external_evaluator)
        end
      when "call"
        result = eval_option_call(expr, values) do |child, scope|
          eval_expr_ext(child, scope, call_trace, external_evaluator)
        end
        result.equal?(UNHANDLED) ? external_evaluator.call(expr, values) : result
      else
        external_evaluator.call(expr, values)
      end
    end

    def validate_expression!(expr)
      return if expr.is_a?(Hash) && expr.key?("kind")

      raise MalformedIfExprError,
            "Expression must be a Hash with a 'kind' key"
    end

    def eval_if_expr(expr, values, call_trace)
      required = %w[condition then_branch else_branch]
      missing = required.reject { |key| expr.key?(key) }
      unless missing.empty?
        raise MalformedIfExprError, "Malformed if_expr node: missing required fields"
      end

      condition = eval_expr(expr.fetch("condition"), values, call_trace)
      validate_condition!(condition)
      selected = condition ? expr.fetch("then_branch") : expr.fetch("else_branch")
      eval_expr(selected, values, call_trace)
    end

    def eval_if_expr_ext(expr, values, call_trace, external_evaluator)
      required = %w[condition then_branch else_branch]
      missing = required.reject { |key| expr.key?(key) }
      unless missing.empty?
        raise MalformedIfExprError, "Malformed if_expr node: missing required fields"
      end

      condition = eval_expr_ext(
        expr.fetch("condition"),
        values,
        call_trace,
        external_evaluator
      )
      validate_condition!(condition)
      selected = condition ? expr.fetch("then_branch") : expr.fetch("else_branch")
      eval_expr_ext(selected, values, call_trace, external_evaluator)
    end

    def validate_condition!(condition)
      return if condition == true || condition == false

      raise ConditionNotBoolError,
            "if_expr condition must evaluate to Bool"
    end

    def eval_literal(expr)
      expr.fetch("value") do
        raise MalformedIfExprError, "Literal expression is missing 'value' key"
      end
    end

    def eval_ref(expr, values)
      name = expr.fetch("name") do
        raise MalformedIfExprError, "Ref expression is missing 'name' key"
      end
      return values.fetch(name) if values.key?(name)

      raise MissingReferenceError, "Reference not found"
    end

    def eval_option_guard(expr)
      unless expr.fetch("version", nil) == "first_class_v1" &&
             expr.fetch("resolved_type", {}).fetch("name", nil) == "Bool" &&
             expr.key?("body")
        option_error!("guard_malformed")
      end

      yield expr.fetch("body")
    end

    def eval_option_construct_v1(expr)
      resolved_type = expr.fetch("resolved_type", {})
      option_error!("construct_type") unless resolved_type.fetch("name", nil) == "Option"

      case expr.fetch("arm", nil)
      when "Some"
        option_error!("construct_some_missing_value") unless expr.key?("value")
        OptionValue.some(yield(expr.fetch("value")))
      when "None"
        option_error!("construct_none_has_value") if expr.key?("value")
        OptionValue.none
      else
        option_error!("construct_arm")
      end
    end

    def eval_option_match(expr, values)
      subject = yield(expr.fetch("subject"), values)
      option = require_option!(subject, "match_wrong_carrier")
      target_arm = option.some? ? "Some" : "None"
      arm = expr.fetch("arms", []).find do |candidate|
        pattern = candidate.fetch("pattern", {})
        pattern.fetch("wildcard", false) || pattern.fetch("arm", nil) == target_arm
      end
      option_error!("match_missing_arm") unless arm

      scope = values.dup
      if option.some?
        bindings = arm.fetch("pattern", {}).fetch("bindings", [])
        option_error!("match_some_binding") unless bindings.length <= 1
        scope[bindings.first] = option.value if bindings.first
      end
      yield(arm.fetch("body"), scope)
    end

    def eval_option_call(expr, values)
      fn = expr.fetch("fn", nil)
      option_error!("legacy_constructor_refused") if LEGACY_OPTION_CALLS.include?(fn)
      return UNHANDLED unless OPTION_CALLS.include?(fn)

      args = expr.fetch("args", [])
      expected_arity = %w[stdlib.option.is_some stdlib.option.is_none].include?(fn) ? 1 : 2
      option_error!("call_arity") unless args.length == expected_arity

      option = require_option!(
        yield(args.fetch(0), values),
        "call_wrong_carrier"
      )
      case fn
      when "or_else", "unwrap_or"
        option.some? ? option.value : yield(args.fetch(1), values)
      when "stdlib.option.is_some"
        option.some?
      when "stdlib.option.is_none"
        option.none?
      when "stdlib.option.map"
        option.none? ? OptionValue.none : OptionValue.some(eval_lambda(args.fetch(1), option.value, values) { |body, scope| yield(body, scope) })
      when "stdlib.option.flat_map", "stdlib.option.and_then"
        return OptionValue.none if option.none?

        mapped = eval_lambda(args.fetch(1), option.value, values) do |body, scope|
          yield(body, scope)
        end
        require_option!(mapped, "hof_result_wrong_carrier")
      end
    end

    def eval_lambda(lambda_node, value, values)
      option_error!("lambda_shape") unless lambda_node.is_a?(Hash) &&
                                            lambda_node.fetch("kind", nil) == "lambda"
      params = lambda_node.fetch("params", [])
      option_error!("lambda_arity") unless params.length == 1

      scope = values.merge(params.first => value)
      yield(lambda_node.fetch("body"), scope)
    end

    def require_option!(value, reason)
      return value if value.is_a?(OptionValue)

      option_error!(reason)
    end

    def legacy_option_node?(expr)
      expr.fetch("kind", nil) == "option_construct" ||
        (expr.fetch("kind", nil) == "variant_construct" &&
         expr.fetch("variant", nil) == "Option")
    end

    def option_error!(reason)
      raise OptionCarrierError, reason
    end

    def unsupported!(kind, fn = nil)
      suffix = fn ? " call #{fn.inspect}" : ""
      raise UnsupportedExpressionKindError,
            "Unsupported expression kind in selected path: #{kind.inspect}#{suffix}. " \
            "Supported: #{SUPPORTED_KINDS.join(", ")}"
    end
  end
end
