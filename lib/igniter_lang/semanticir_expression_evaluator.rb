# frozen_string_literal: true

# IgniterLang::SemanticIRExpressionEvaluator
#
# Internal Slice 1 / Slice 2 SemanticIR expression evaluator.
#
# Authorization: S3-R199-C1-A (Slice 1), S3-R201-C1-A (Slice 2 hook)
# Track: branch-conditional-if-expr-live-runtime-evaluator-implementation-v0
#        branch-conditional-if-expr-proof-runtime-consumer-v0
#
# Boundary:
#   internal, direct-require-only, not root-required
#   supported expression kinds: literal, ref, if_expr
#   not integrated into RuntimeSmoke, CompilerOrchestrator, CompilerResult,
#   CompilationReport, Diagnostics, public API/CLI, release harness, or Spark
#
# Semantics:
#   if_expr evaluation is lazy:
#     1. Evaluate condition first.
#     2. Require runtime Bool exactly: true or false. No truthy/falsy coercion.
#     3. If condition is true, evaluate only then_branch.
#     4. If condition is false, evaluate only else_branch.
#     5. Return the selected branch value.
#     6. Apply same rules recursively for nested if_expr.
#
#   external_evaluator: hook (Slice 2, backward-compatible):
#     When external_evaluator: is provided and a selected-path expression kind
#     is unsupported by this evaluator, the expression is delegated as:
#       external_evaluator.call(expr, values)
#     Not called for non-selected branches. Not called before condition evaluation.
#     If the callable raises, the exception propagates unchanged.
#     Omitting external_evaluator: preserves Slice 1 behavior exactly (no delegation).
#
# Internal diagnostics (non-canonical, not OOF-RT-*, not Diagnostics/reports):
#   Reason labels are proof-debug/human-readable only.

module IgniterLang
  class SemanticIRExpressionEvaluator
    # -------------------------------------------------------------------------
    # Internal exception hierarchy
    # All internal to this class; not integrated with Diagnostics, CompilerResult,
    # CompilationReport, or public API/CLI surface.
    # -------------------------------------------------------------------------

    # Base class for all evaluator errors
    Error = Class.new(StandardError)

    # if_expr node is missing a required field (condition, then_branch, else_branch)
    MalformedIfExprError = Class.new(Error)

    # Condition value is not exactly true or false (no truthy/falsy coercion)
    ConditionNotBoolError = Class.new(Error)

    # Expression kind is not supported by this evaluator (selected-path only)
    UnsupportedExpressionKindError = Class.new(Error)

    # Referenced name is not present in the values hash
    MissingReferenceError = Class.new(Error)

    # -------------------------------------------------------------------------
    # Supported expression kinds (Slice 1 core)
    # -------------------------------------------------------------------------

    SUPPORTED_KINDS = %w[literal ref if_expr].freeze

    # -------------------------------------------------------------------------
    # Public interface
    # -------------------------------------------------------------------------

    # Evaluate a SemanticIR expression node.
    #
    # expr               - Hash representing a SemanticIR expression node.
    #                      Must have a "kind" key.
    # values             - Hash (String keys) of resolved node names to runtime values.
    # call_trace:        - Optional Array; if provided, evaluated expression kinds
    #                      are appended in order. Proof/debug evidence only; must not
    #                      be treated as dependency authority.
    # external_evaluator: - Optional callable (Slice 2 adapter hook). When provided
    #                      and the selected-path expression kind is unsupported by
    #                      this evaluator, the expression is delegated as:
    #                        external_evaluator.call(expr, values)
    #                      The callable must return the evaluated value or raise.
    #                      If it raises, the exception propagates unchanged.
    #                      Not called for non-selected branches.
    #                      Not called before condition evaluation.
    #                      Omit to preserve Slice 1 behavior (no delegation).
    def evaluate(expr, values = {}, call_trace: nil, external_evaluator: nil)
      if external_evaluator
        # Slice 2 path: use the extended evaluation pipeline with delegation.
        # Authorization: S3-R201-C1-A
        eval_expr_ext(expr, values, call_trace, external_evaluator)
      else
        # Slice 1 path: use the original evaluation pipeline (no delegation).
        # Authorization: S3-R199-C1-A
        eval_expr(expr, values, call_trace)
      end
    end

    private

    # =========================================================================
    # Slice 1 core evaluation pipeline (original, unmodified).
    # These methods are not changed to preserve Slice 1 proof structural checks.
    # =========================================================================

    # Core recursive evaluator (Slice 1)
    def eval_expr(expr, values, call_trace)
      unless expr.is_a?(Hash) && expr.key?("kind")
        raise MalformedIfExprError,
              "Expression must be a Hash with a 'kind' key; got #{expr.class}"
      end

      kind = expr.fetch("kind")
      call_trace&.push(kind)

      case kind
      when "literal"
        eval_literal(expr)

      when "ref"
        eval_ref(expr, values)

      when "if_expr"
        eval_if_expr(expr, values, call_trace)

      else
        # Unknown expression kind in selected path: fail closed.
        # This is reached only when the kind is actually selected for evaluation.
        raise UnsupportedExpressionKindError,
              "Unsupported expression kind in selected path: #{kind.inspect}. " \
              "Supported: #{SUPPORTED_KINDS.join(", ")}"
      end
    end

    # Evaluate an if_expr expression node with lazy semantics (Slice 1).
    #
    # Structural proof of selected-branch-only evaluation (LRT-IF12):
    #   eval_if_expr passes ONLY the selected branch to eval_expr.
    #   - When cond_val == true, ONLY then_branch is passed (line A).
    #   - When cond_val == false, ONLY else_branch is passed (line B).
    #   The two Ruby `if` arms are mutually exclusive; the non-selected branch
    #   Hash is never passed to eval_expr in normal evaluation.
    #
    # This preserves the counterfactual audit stance: the explicit branch
    # structure is retained in the node, allowing a future audit layer to
    # inspect static branch metadata without requiring eager evaluation here.
    def eval_if_expr(expr, values, call_trace)
      # LRT-IF8: fail closed for malformed if_expr
      required_keys = %w[condition then_branch else_branch]
      missing = required_keys.reject { |k| expr.key?(k) }
      unless missing.empty?
        raise MalformedIfExprError,
              "Malformed if_expr node: missing required keys #{missing.inspect}. " \
              "Internal reason: runtime.if_expr_malformed"
      end

      # LRT-IF5: evaluate condition first; condition failure propagates before
      # any branch is touched
      cond_val = eval_expr(expr.fetch("condition"), values, call_trace)

      # LRT-IF7: runtime Bool guard; no truthy/falsy coercion
      unless cond_val == true || cond_val == false
        raise ConditionNotBoolError,
              "if_expr condition must evaluate to Bool (true or false); " \
              "got #{cond_val.class}: #{cond_val.inspect}. " \
              "Internal reason: runtime.if_expr_condition_not_bool"
      end

      # LRT-IF1 / LRT-IF2 / LRT-IF3 / LRT-IF4: lazy branch selection
      # Only the selected branch is passed to eval_expr.
      if cond_val == true
        eval_expr(expr.fetch("then_branch"), values, call_trace) # line A: then_branch only
      else
        eval_expr(expr.fetch("else_branch"), values, call_trace) # line B: else_branch only
      end
    end

    # =========================================================================
    # Slice 2 extended evaluation pipeline (with external_evaluator delegation).
    # Authorization: S3-R201-C1-A
    # These methods mirror the Slice 1 pipeline but thread the external_evaluator
    # callable through for selected-path delegation of unsupported kinds.
    # =========================================================================

    # Core recursive evaluator (Slice 2 — with external_evaluator)
    def eval_expr_ext(expr, values, call_trace, external_evaluator)
      unless expr.is_a?(Hash) && expr.key?("kind")
        raise MalformedIfExprError,
              "Expression must be a Hash with a 'kind' key; got #{expr.class}"
      end

      kind = expr.fetch("kind")
      call_trace&.push(kind)

      case kind
      when "literal"
        eval_literal(expr)

      when "ref"
        eval_ref(expr, values)

      when "if_expr"
        eval_if_expr_ext(expr, values, call_trace, external_evaluator)

      else
        # PRT-IF3 / PRT-IF4 / PRT-IF5: selected-path kind unsupported by evaluator.
        # Delegate to external_evaluator (proof RuntimeMachine local handler).
        # External evaluator exceptions propagate unchanged (not wrapped).
        # Not reached for non-selected branches (eval_if_expr_ext guarantees this).
        external_evaluator.call(expr, values)
      end
    end

    # Evaluate an if_expr expression node with lazy semantics (Slice 2).
    #
    # Structural proof of selected-branch-only evaluation (PRT-IF6 / PRT-IF7):
    #   eval_if_expr_ext passes ONLY the selected branch to eval_expr_ext.
    #   - When cond_val == true, ONLY then_branch is passed (line A-ext).
    #   - When cond_val == false, ONLY else_branch is passed (line B-ext).
    #   The two Ruby `if` arms are mutually exclusive; the non-selected branch
    #   Hash is never passed to eval_expr_ext.
    #   Therefore external_evaluator is never called for the non-selected branch.
    def eval_if_expr_ext(expr, values, call_trace, external_evaluator)
      # PRT-IF10: fail closed for malformed if_expr
      required_keys = %w[condition then_branch else_branch]
      missing = required_keys.reject { |k| expr.key?(k) }
      unless missing.empty?
        raise MalformedIfExprError,
              "Malformed if_expr node: missing required keys #{missing.inspect}. " \
              "Internal reason: runtime.if_expr_malformed"
      end

      # PRT-IF8: evaluate condition first; condition failure propagates before
      # any branch is touched
      cond_val = eval_expr_ext(expr.fetch("condition"), values, call_trace, external_evaluator)

      # PRT-IF9: runtime Bool guard; no truthy/falsy coercion
      unless cond_val == true || cond_val == false
        raise ConditionNotBoolError,
              "if_expr condition must evaluate to Bool (true or false); " \
              "got #{cond_val.class}: #{cond_val.inspect}. " \
              "Internal reason: runtime.if_expr_condition_not_bool"
      end

      # PRT-IF6 / PRT-IF7: lazy branch selection.
      # Only the selected branch is passed to eval_expr_ext.
      # external_evaluator is threaded through so selected branches of unsupported
      # kinds can be delegated. It is never reached for the non-selected branch.
      if cond_val == true
        eval_expr_ext(expr.fetch("then_branch"), values, call_trace, external_evaluator) # line A-ext: then_branch only
      else
        eval_expr_ext(expr.fetch("else_branch"), values, call_trace, external_evaluator) # line B-ext: else_branch only
      end
    end

    # =========================================================================
    # Shared helpers (used by both Slice 1 and Slice 2 paths)
    # =========================================================================

    # Evaluate a literal expression node.
    # Returns the static value embedded in the node.
    def eval_literal(expr)
      expr.fetch("value") do
        raise MalformedIfExprError,
              "Literal expression is missing 'value' key"
      end
    end

    # Evaluate a ref expression node.
    # Looks up the referenced name in the values hash.
    def eval_ref(expr, values)
      name = expr.fetch("name") do
        raise MalformedIfExprError, "Ref expression is missing 'name' key"
      end

      unless values.key?(name)
        raise MissingReferenceError,
              "Reference '#{name}' not found in values. " \
              "Available: #{values.keys.sort.inspect}"
      end

      values.fetch(name)
    end
  end
end
