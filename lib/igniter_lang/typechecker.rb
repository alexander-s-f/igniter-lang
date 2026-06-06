# frozen_string_literal: true

require "digest"

module IgniterLang
  class TypeChecker
    DEFAULT_VERSION = "typed-pass-executable-proof-v0"

    def initialize(typechecker_version: DEFAULT_VERSION)
      @typechecker_version = typechecker_version
    end

    def typecheck(classified_program)
      @type_shapes = type_shapes(classified_program)
      @assumption_registry = classified_program.fetch("assumption_registry", [])
      @type_shapes["Assumption"] = assumption_shape if assumptions_present?(classified_program)
      @assumption_errors = assumption_errors_by_name(@assumption_registry)
      @olap_env = olap_env(classified_program.fetch("olap_points", []))
      @olap_errors = olap_declaration_errors(@olap_env)
      typed_contracts = classified_program.fetch("contracts").map do |contract|
        typecheck_contract(contract)
      end

      result = {
        "kind" => "typed_program",
        "typechecker_version" => @typechecker_version,
        "program_id" => program_id(classified_program),
        "classified_program_id" => classified_program.fetch("program_id"),
        "source_path" => classified_program.fetch("source_path"),
        "source_hash" => classified_program.fetch("source_hash"),
        "grammar_version" => classified_program.fetch("grammar_version"),
        "module" => classified_program.fetch("module"),
        "type_env" => @type_shapes,
        "contracts" => typed_contracts,
        "type_errors" => typed_contracts.flat_map { |contract| contract.fetch("type_errors") },
        "semantic_ir_ref" => nil
      }
      result["assumption_registry"] = @assumption_registry unless @assumption_registry.empty?
      result["olap_points"] = @olap_env.values.map { |decl| decl.fetch("semantic_node") } unless @olap_env.empty?
      type_warnings = typed_contracts.flat_map { |contract| contract.fetch("type_warnings", []) }
      result["type_warnings"] = type_warnings unless type_warnings.empty?
      result
    end

    private

    def program_id(classified_program)
      seed = [
        classified_program.fetch("program_id"),
        classified_program.fetch("source_hash"),
        @typechecker_version
      ].join("|")
      "typed_pass/#{Digest::SHA256.hexdigest(seed)[0, 16]}"
    end

    def type_shapes(classified_program)
      classified_program.fetch("type_declarations").each_with_object({}) do |type, shapes|
        shapes[type.fetch("name")] = type.fetch("fields", []).each_with_object({}) do |field, fields|
          fields[field.fetch("name")] = type_ir(normalize_type(field.fetch("type_annotation")))
        end
      end
    end

    def typecheck_contract(classified_contract)
      declared_oofs = classified_contract.fetch("oof_log")
      assumption_refs = classified_contract.fetch("assumption_refs", [])
      type_errors = declared_oofs + @olap_errors + assumption_refs.flat_map { |name| @assumption_errors.fetch(name, []) }
      type_warnings = []
      symbol_types = {}
      typed_decls = []
      invariant_effects = []  # [{"name" => ..., "effect" => "warns"|"uncertain"|"metric"}] for output propagation

      classified_contract.fetch("declarations").each do |decl|
        case decl.fetch("kind")
        when "input"
          type = type_ir(decl.fetch("type_annotation"))
          symbol_types[decl.fetch("name")] = type
          typed_decls << typed_decl(decl, type, nil, [])
        when "read"
          type = type_ir(decl.fetch("type_annotation"))
          symbol_types[decl.fetch("name")] = type
          typed_decls << typed_decl(decl, type, nil, [])
        when "stream"
          # stream declarations are ESCAPE; register their type for body-escape checks
          type = decl.key?("type_annotation") ? type_ir(decl.fetch("type_annotation")) : type_ir("Unknown")
          symbol_types[decl.fetch("name")] = type
          typed_decls << typed_decl(decl, type, nil, [])
        when "window"
          typed_decls << typed_decl(decl, type_ir("Window"), nil, [])
        when "fold_stream"
          # OOF-S3: ESCAPE construct (stream ref) inside fold_stream accumulator function body
          stream_symbols = stream_symbol_names(classified_contract)
          check_fold_stream_body(decl, stream_symbols, type_errors)
          result_type = fold_stream_result_type(decl)
          symbol_types[decl.fetch("name")] = result_type
          typed_decls << typed_decl(decl, result_type, decl.fetch("expr", nil), decl.fetch("deps", []))
        when "uses_assumptions"
          type = type_ir("Assumption")
          symbol_types[decl.fetch("name")] = type
          typed_decls << typed_decl(decl, type, nil, [])
        when "invariant"
          # TINV-1/2/3: Resolve predicate_ref, validate overridable_with, compute output_effect
          check_invariant(decl, symbol_types, type_errors, invariant_effects)
          typed_decls << typed_decl_invariant(decl, symbol_types)
        when "compute"
          typed_expr = infer_expr(decl.fetch("expr"), symbol_types, type_errors, type_warnings, decl.fetch("name"))
          validate_declared_olap_type(decl, typed_expr, type_errors)
          symbol_types[decl.fetch("name")] = typed_expr.fetch("resolved_type")
          typed_decls << typed_decl(decl, typed_expr.fetch("resolved_type"), typed_expr, typed_expr.fetch("deps"))
        when "output"
          expected = type_ir(decl.fetch("type_annotation"))
          actual = symbol_types.fetch(decl.fetch("name"), type_ir("Unknown"))
          if type_name(actual) != type_name(expected) && !blocking_rule_present?(type_errors)
            type_errors << type_mismatch(expected, actual, decl.fetch("name"))
          end
          # TINV-4: propagate invariant output effects to output nodes
          typed_decls << typed_decl_output(decl, expected, invariant_effects)
        end
      end

      status = type_errors.empty? ? "accepted" : "blocked"
      result = {
        "kind" => "typed_contract",
        "contract_id" => classified_contract.fetch("contract_id"),
        "name" => classified_contract.fetch("name"),
        "modifier" => classified_contract.fetch("modifier", "pure"),
        "status" => status,
        "fragment_class" => classified_contract.fetch("fragment_class"),
        "symbols" => symbol_types.keys.sort.map do |name|
          { "name" => name, "type" => symbol_types.fetch(name), "resolved" => type_name(symbol_types.fetch(name)) != "Unknown" }
        end,
        "declarations" => typed_decls,
        "type_errors" => dedupe_errors(type_errors)
      }
      result["assumption_refs"] = assumption_refs unless assumption_refs.empty?
      warnings = dedupe_errors(type_warnings)
      result["type_warnings"] = warnings unless warnings.empty?
      result
    end

    def typed_decl(decl, type, expr, deps)
      result = {
        "decl_id" => decl.fetch("decl_id"),
        "kind" => decl.fetch("kind"),
        "name" => decl.fetch("name"),
        "fragment_class" => decl.fetch("fragment_class"),
        "type" => type,
        "deps" => deps
      }
      result["expr"] = expr if expr
      result["semantic_node"] = expr.fetch("semantic_node") if expr&.key?("semantic_node")
      %w[node_fragment_class value_fragment_class required_capability temporal_axis].each do |key|
        result[key] = decl.fetch(key) if decl.key?(key)
      end
      %w[from lifecycle].each do |key|
        result[key] = decl.fetch(key) if decl.key?(key)
      end
      %w[bound options window_ref key window_kind size period idle on_close fn_ref init stream_ref].each do |key|
        result[key] = decl.fetch(key) if decl.key?(key)
      end
      result
    end

    def assumption_shape
      {
        "kind" => type_ir("Symbol"),
        "statement" => type_ir("String"),
        "strength" => type_ir("Decimal"),
        "source" => type_ir("String")
      }
    end

    def assumptions_present?(classified_program)
      @assumption_registry.any? ||
        classified_program.fetch("contracts").any? { |contract| contract.fetch("assumption_refs", []).any? }
    end

    def assumption_errors_by_name(registry)
      registry.each_with_object({}) do |entry, errors|
        strength = entry.fetch("fields", {}).fetch("strength", nil)
        next if strength.nil? || valid_assumption_strength?(strength)

        errors[entry.fetch("name")] ||= []
        errors[entry.fetch("name")] << oof(
          "TASSUMP-1",
          "assumption strength must be between 0.0 and 1.0",
          "assumption:#{entry.fetch("name")}"
        )
      end
    end

    def valid_assumption_strength?(strength)
      strength.is_a?(Numeric) && strength >= 0.0 && strength <= 1.0
    end

    def infer_expr(expr, symbol_types, type_errors, type_warnings, node_name)
      case expr.fetch("kind")
      when "literal"
        type = type_ir(expr.fetch("type_tag"))
        typed_expr("literal", type, [], "value" => expr.fetch("value"), "literal_type" => literal_type(type_name(type)))
      when "symbol"
        typed_expr("symbol", type_ir("Symbol"), [], "value" => expr.fetch("value"))
      when "ref"
        name = expr.fetch("name")
        type = symbol_types.fetch(name, @olap_env.fetch(name, {}).fetch("type", type_ir("Unknown")))
        if name == "l" && type_name(type) == "Unknown"
          puts "DEBUG: unresolved l backtrace:"
          puts caller
        end
        type_errors << oof("OOF-P1", "Unresolved symbol: #{name}", node_name) if type_name(type) == "Unknown" && !rule_present?(type_errors, "OOF-P1")
        typed_expr("ref", type, [name], "name" => name)
      when "field_access"
        object = infer_expr(expr.fetch("object"), symbol_types, type_errors, type_warnings, node_name)
        object_type = type_name(object.fetch("resolved_type"))
        field_type = @type_shapes.fetch(object_type, {})[expr.fetch("field")] || type_ir("Unknown")
        if type_name(field_type) == "Unknown"
          type_errors << oof("OOF-P1", "Unresolved field: #{object_type}.#{expr.fetch("field")}", node_name)
        end
        typed_expr(
          "field_access",
          field_type,
          object.fetch("deps"),
          "object" => object,
          "field" => expr.fetch("field")
        )
      when "binary_op"
        infer_binary(expr, symbol_types, type_errors, type_warnings, node_name)
      when "call"
        infer_call(expr, symbol_types, type_errors, type_warnings, node_name)
      when "index_access"
        infer_index_access(expr, symbol_types, type_errors, type_warnings, node_name)
      when "if_expr"
        infer_if_expr(expr, symbol_types, type_errors, type_warnings, node_name)
      else
        type_errors << oof("OOF-TY0", "Unsupported expression kind: #{expr.fetch("kind")}", node_name)
        typed_expr("unsupported", type_ir("Unknown"), [], "source_kind" => expr.fetch("kind"))
      end
    end

    def infer_call(expr, symbol_types, type_errors, type_warnings, node_name)
      fn = expr.fetch("fn")
      args = expr.fetch("args")
      case fn
      when "history_at"
        infer_history_at(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when "bihistory_at"
        infer_bihistory_at(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when "olap_rollup"
        infer_olap_rollup(fn, args, symbol_types, type_errors, type_warnings, node_name)
      else
        type_errors << oof("OOF-TY0", "Unknown function: #{fn}", node_name)
        typed_expr("call", type_ir("Unknown"), [], "fn" => fn, "args" => [])
      end
    end

    def infer_history_at(fn, args, symbol_types, type_errors, type_warnings, node_name)
      if args.length < 2
        type_errors << oof_alias("OOF-H1", "history_at requires as_of argument", node_name, ["OOF-TM1"])
        return typed_expr("call", type_ir("Unknown"), [], "fn" => fn, "args" => [])
      end

      history_ref = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      as_of_ref = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
      unless type_name(as_of_ref.fetch("resolved_type")) == "DateTime" ||
             type_name(as_of_ref.fetch("resolved_type")) == "Unknown"
        type_errors << oof_alias("OOF-BT1", "history_at: as_of must be DateTime, got #{type_name(as_of_ref.fetch("resolved_type"))}", node_name, ["OOF-TM3"])
      end
      result_type = option_type_from(history_ref.fetch("resolved_type"))
      typed_expr(
        "call",
        result_type,
        history_ref.fetch("deps") + as_of_ref.fetch("deps"),
        "fn" => fn,
        "args" => [history_ref, as_of_ref],
        "semantic_node" => temporal_access_node(node_name, "valid_time", history_ref, [as_of_ref], result_type)
      )
    end

    def infer_bihistory_at(fn, args, symbol_types, type_errors, type_warnings, node_name)
      if args.length < 2
        type_errors << oof_alias("OOF-BT2", "bihistory_at requires valid_time (vt) argument", node_name, ["OOF-TM4"])
        return typed_expr("call", type_ir("Unknown"), [], "fn" => fn, "args" => [])
      end
      if args.length < 3
        type_errors << oof_alias("OOF-BT3", "bihistory_at requires transaction_time (tt) argument", node_name, ["OOF-TM5"])
        return typed_expr("call", type_ir("Unknown"), [], "fn" => fn, "args" => [])
      end

      history_ref = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      vt_ref = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
      tt_ref = infer_expr(args[2], symbol_types, type_errors, type_warnings, node_name)
      [vt_ref, tt_ref].each_with_index do |axis_ref, idx|
        axis_name = idx.zero? ? "valid_time" : "transaction_time"
        unless type_name(axis_ref.fetch("resolved_type")) == "DateTime" ||
               type_name(axis_ref.fetch("resolved_type")) == "Unknown"
          type_errors << oof_alias("OOF-BT4", "bihistory_at: #{axis_name} must be DateTime, got #{type_name(axis_ref.fetch("resolved_type"))}", node_name, ["OOF-TM6"])
        end
      end
      result_type = option_type_from(history_ref.fetch("resolved_type"))
      typed_expr(
        "call",
        result_type,
        history_ref.fetch("deps") + vt_ref.fetch("deps") + tt_ref.fetch("deps"),
        "fn" => fn,
        "args" => [history_ref, vt_ref, tt_ref],
        "semantic_node" => temporal_access_node(node_name, "bitemporal", history_ref, [vt_ref, tt_ref], result_type)
      )
    end

    def temporal_access_node(node_name, axis, history_ref, axis_refs, result_type)
      capability = axis == "bitemporal" ? "bihistory_read" : "history_read"
      result = {
        "kind" => "temporal_access_node",
        "name" => node_name,
        "source_ref" => history_ref.fetch("name", nil),
        "axis" => axis,
        "temporal_axis" => axis,
        "history_ref" => history_ref.fetch("name", nil),
        "axis_refs" => axis_refs.map { |ref| ref.fetch("name", nil) }.compact,
        "coordinate_refs" => temporal_coordinate_refs(axis, axis_refs),
        "result_type" => result_type,
        "node_fragment_class" => "temporal",
        "value_fragment_class" => "core",
        "required_capability" => capability,
        "required_caps" => [capability],
        "deps" => history_ref.fetch("deps", []) + axis_refs.flat_map { |ref| ref.fetch("deps", []) },
        "evidence_policy" => axis == "bitemporal" ? "link_selected_event_observation" : "link_selected_append_observation",
        "fragment" => "temporal"
      }
      if axis == "bitemporal"
        result["valid_time_ref"] = axis_refs[0]&.fetch("name", nil)
        result["transaction_time_ref"] = axis_refs[1]&.fetch("name", nil)
      else
        result["as_of_ref"] = axis_refs[0]&.fetch("name", nil)
      end
      result
    end

    def temporal_coordinate_refs(axis, axis_refs)
      if axis == "bitemporal"
        {
          "valid_time" => axis_refs[0]&.fetch("name", nil),
          "transaction_time" => axis_refs[1]&.fetch("name", nil)
        }
      else
        { "as_of" => axis_refs[0]&.fetch("name", nil) }
      end
    end

    def infer_index_access(expr, symbol_types, type_errors, type_warnings, node_name)
      object = expr.fetch("object")
      return unsupported_index_access(expr, type_errors, node_name) unless object.fetch("kind") == "ref"

      olap_name = object.fetch("name")
      olap_decl = @olap_env[olap_name]
      return unsupported_index_access(expr, type_errors, node_name) unless olap_decl

      index = expr.fetch("index")
      unless index.fetch("kind") == "slice_record"
        type_errors << oof("OOF-O4", "OLAPPoint access requires a dimension slice record", node_name)
        return typed_expr("index_access", type_ir("Unknown"), [olap_name], "object" => typed_expr("ref", olap_decl.fetch("type"), [olap_name], "name" => olap_name))
      end

      slices = index.fetch("fields")
      dims = olap_decl.fetch("dimensions")
      missing = dims.keys.sort - slices.keys.sort
      missing.each do |dim|
        type_errors << oof("OOF-O4", "OLAPPoint access missing required dimension: #{dim}", node_name)
      end

      typed_slices = slices.keys.sort.map do |dim|
        expected = dims[dim]
        value = infer_expr(slices.fetch(dim), symbol_types, type_errors, type_warnings, node_name)
        if expected && !unknown?(value.fetch("resolved_type")) && !same_type?(expected, value.fetch("resolved_type"))
          type_errors << oof("OOF-O5", "OLAPPoint dimension '#{dim}' expected #{type_display(expected)}, got #{type_display(value.fetch("resolved_type"))}", node_name)
        end
        {
          "dim" => dim,
          "value" => value,
          "value_ref" => slice_value_ref(slices.fetch(dim)),
          "expected_type" => expected || type_ir("Unknown")
        }
      end

      semantic_node = olap_access_node(node_name, olap_decl, typed_slices)
      typed_expr(
        "index_access",
        olap_decl.fetch("measure_type"),
        typed_slices.flat_map { |slice| slice.fetch("value").fetch("deps") },
        "object" => typed_expr("ref", olap_decl.fetch("type"), [olap_name], "name" => olap_name),
        "slices" => typed_slices,
        "semantic_node" => semantic_node
      )
    end

    def unsupported_index_access(expr, type_errors, node_name)
      type_errors << oof("OOF-TY0", "Unsupported index access", node_name)
      typed_expr("index_access", type_ir("Unknown"), [], "source_kind" => expr.fetch("kind"))
    end

    def infer_olap_rollup(fn, args, symbol_types, type_errors, type_warnings, node_name)
      if args.length < 2
        type_errors << oof("OOF-O4", "olap_rollup requires point and dimension arguments", node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => fn, "args" => [])
      end

      olap_ref = args[0]
      dim_arg = args[1]
      unless olap_ref.fetch("kind") == "ref" && dim_arg.fetch("kind") == "symbol"
        type_errors << oof("OOF-O4", "olap_rollup requires a named OLAPPoint and dimension symbol", node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => fn, "args" => [])
      end

      olap_decl = @olap_env[olap_ref.fetch("name")]
      unless olap_decl
        type_errors << oof("OOF-P1", "Unresolved symbol: #{olap_ref.fetch("name")}", node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => fn, "args" => [])
      end

      dim = dim_arg.fetch("value")
      unless olap_decl.fetch("dimensions").key?(dim)
        type_errors << oof("OOF-O4", "OLAPPoint access missing required dimension: #{dim}", node_name)
      end
      unless olap_decl.fetch("indexed").include?(dim) || explicit_scatter_gather?(args)
        type_warnings << oof("OOF-O2", "rollup over non-indexed dimension may be slow; add to indexed:", node_name).merge("severity" => "warning")
      end

      remaining_dims = olap_decl.fetch("dimensions").reject { |name, _type| name == dim }
      result_type = olap_type(olap_decl.fetch("measure_type"), remaining_dims)
      typed_expr(
        "call",
        result_type,
        [olap_decl.fetch("name")],
        "fn" => fn,
        "args" => [
          typed_expr("ref", olap_decl.fetch("type"), [olap_decl.fetch("name")], "name" => olap_decl.fetch("name")),
          typed_expr("symbol", type_ir("Symbol"), [], "value" => dim)
        ]
      )
    end

    def option_type_from(history_type)
      inner = history_type.fetch("params", []).first
      inner_name = inner.is_a?(Hash) ? inner.fetch("name", "Unknown") : (inner || "Unknown")
      { "name" => "Option", "params" => [{ "name" => inner_name, "params" => [] }] }
    end

    def infer_if_expr(expr, symbol_types, type_errors, type_warnings, node_name)
      cond_raw   = expr.fetch("cond")
      then_block = expr.fetch("then")
      else_block = expr.fetch("else")

      # OOF-IF2: else is required
      if else_block.nil?
        type_errors << oof("OOF-IF2", "if_expr requires an else branch", node_name)
        cond_typed = infer_expr(cond_raw, symbol_types, type_errors, type_warnings, node_name)
        return typed_expr("if_expr", type_ir("Unknown"), cond_typed.fetch("deps"),
                          "cond" => cond_typed)
      end

      then_final = then_block.fetch("return_expr", nil)
      else_final = else_block.fetch("return_expr", nil)

      # OOF-IF4: branches must be value-producing (non-empty final expression)
      if then_final.nil? || else_final.nil?
        type_errors << oof("OOF-IF4", "if_expr branches must be value-producing", node_name)
        cond_typed = infer_expr(cond_raw, symbol_types, type_errors, type_warnings, node_name)
        return typed_expr("if_expr", type_ir("Unknown"), cond_typed.fetch("deps"),
                          "cond" => cond_typed)
      end

      # Infer condition
      cond_typed = infer_expr(cond_raw, symbol_types, type_errors, type_warnings, node_name)
      cond_type  = cond_typed.fetch("resolved_type")

      # OOF-IF1: condition must resolve to canonical Bool {"name":"Bool","params":[]}
      unless type_name(cond_type) == "Bool" || type_name(cond_type) == "Unknown"
        type_errors << oof("OOF-IF1", "if_expr condition must be Bool, got #{type_name(cond_type)}", node_name)
      end

      # Infer branch final expressions
      then_typed = infer_expr(then_final, symbol_types, type_errors, type_warnings, node_name)
      else_typed = infer_expr(else_final, symbol_types, type_errors, type_warnings, node_name)

      then_type = then_typed.fetch("resolved_type")
      else_type = else_typed.fetch("resolved_type")

      # OOF-IF3: then/else final value types must exact-match
      result_type = if !unknown?(then_type) && !unknown?(else_type) && type_name(then_type) != type_name(else_type)
                      type_errors << oof("OOF-IF3", "if_expr branch types must match: then=#{type_name(then_type)}, else=#{type_name(else_type)}", node_name)
                      type_ir("Unknown")
                    elsif unknown?(then_type)
                      else_type
                    else
                      then_type
                    end

      # Union dependencies: condition + then + else (recursive nested deps included automatically)
      all_deps = (cond_typed.fetch("deps") + then_typed.fetch("deps") + else_typed.fetch("deps")).uniq

      # TypeChecker shape: cond/then/else with branch wrappers (distinct from SemanticIR shape)
      typed_expr(
        "if_expr",
        result_type,
        all_deps,
        "cond" => cond_typed,
        "then" => { "kind" => "branch", "expr" => then_typed },
        "else" => { "kind" => "branch", "expr" => else_typed }
      )
    end

    def infer_binary(expr, symbol_types, type_errors, type_warnings, node_name)
      left = infer_expr(expr.fetch("left"), symbol_types, type_errors, type_warnings, node_name)
      right = infer_expr(expr.fetch("right"), symbol_types, type_errors, type_warnings, node_name)
      operator, result_type = operator_type(expr.fetch("op"), left.fetch("resolved_type"), right.fetch("resolved_type"), type_errors, node_name)
      typed_expr(
        "call",
        result_type,
        left.fetch("deps") + right.fetch("deps"),
        "fn" => operator,
        "args" => [left, right]
      )
    end

    def operator_type(op, left, right, type_errors, node_name)
      left_name = type_name(left)
      right_name = type_name(right)
      case op
      when "+"
        type_errors << type_mismatch(type_ir("Integer"), type_ir("#{left_name}+#{right_name}"), node_name) unless unknown?(left, right) || left_name == "Integer" && right_name == "Integer"
        ["stdlib.integer.add", type_ir("Integer")]
      when "-"
        type_errors << type_mismatch(type_ir("Integer"), type_ir("#{left_name}-#{right_name}"), node_name) unless unknown?(left, right) || left_name == "Integer" && right_name == "Integer"
        ["stdlib.integer.sub", type_ir("Integer")]
      when "*"
        type_errors << type_mismatch(type_ir("Integer"), type_ir("#{left_name}*#{right_name}"), node_name) unless unknown?(left, right) || left_name == "Integer" && right_name == "Integer"
        ["stdlib.integer.mul", type_ir("Integer")]
      when "/"
        type_errors << type_mismatch(type_ir("Integer"), type_ir("#{left_name}/#{right_name}"), node_name) unless unknown?(left, right) || left_name == "Integer" && right_name == "Integer"
        ["stdlib.integer.div", type_ir("Integer")]
      when ">"
        type_errors << type_mismatch(type_ir("Integer"), type_ir("#{left_name}+#{right_name}"), node_name) unless unknown?(left, right) || left_name == "Integer" && right_name == "Integer"
        ["stdlib.integer.gt", type_ir("Bool")]
      when "&&"
        type_errors << type_mismatch(type_ir("Bool"), type_ir("#{left_name}+#{right_name}"), node_name) unless unknown?(left, right) || left_name == "Bool" && right_name == "Bool"
        ["stdlib.bool.and", type_ir("Bool")]
      else
        type_errors << oof("OOF-TY0", "Unsupported operator: #{op}", node_name)
        ["stdlib.unsupported.#{op}", type_ir("Unknown")]
      end
    end

    def typed_expr(kind, type, deps, extra)
      { "kind" => kind }.merge(extra).merge("resolved_type" => type, "deps" => deps.uniq)
    end

    def type_ir(annotation)
      return annotation.dup if annotation.is_a?(Hash) && annotation.key?("name")

      name = annotation.is_a?(Hash) ? annotation.fetch("name", "Unknown") : annotation.to_s
      params = annotation.is_a?(Hash) ? annotation.fetch("params", []).map { |p| type_ir(p) } : []
      { "name" => name, "params" => params }
    end

    def dims_record_type(dims)
      {
        "name" => "DimsRecord",
        "params" => [],
        "dims" => dims.transform_values { |type| type_ir(type) }
      }
    end

    def olap_type(measure_type, dims)
      {
        "name" => "OLAPPoint",
        "params" => [measure_type, dims_record_type(dims)]
      }
    end

    def olap_env(olap_points)
      olap_points.each_with_object({}) do |point, env|
        dimensions = point.fetch("dimensions", {}).transform_values { |type| type_ir(type) }
        measure_type = type_ir(point.fetch("measure", point.fetch("measure_type", "Unknown")))
        name = point.fetch("name")
        semantic_node = {
          "kind" => "olap_point_decl",
          "name" => name,
          "dimensions" => dimensions.transform_values { |type| type_display(type) },
          "measure_type" => type_display(measure_type),
          "granularity" => point.fetch("granularity", {}),
          "source_ref" => point.fetch("source_ref", nil),
          "indexed" => point.fetch("indexed", [])
        }
        env[name] = {
          "name" => name,
          "dimensions" => dimensions,
          "measure_type" => measure_type,
          "granularity" => point.fetch("granularity", {}),
          "source" => point.fetch("source", nil),
          "source_ref" => point.fetch("source_ref", nil),
          "seeded_data" => point.fetch("seeded_data", false),
          "indexed" => point.fetch("indexed", []),
          "type" => olap_type(measure_type, dimensions),
          "semantic_node" => semantic_node
        }
      end
    end

    def olap_declaration_errors(olap_env)
      olap_env.values.filter_map do |point|
        next if point.fetch("source") || point.fetch("source_ref") || point.fetch("seeded_data")

        oof("OOF-O3", "OLAPPoint must declare a source function or be populated via stream snapshot", point.fetch("name"))
      end
    end

    def validate_declared_olap_type(decl, typed_expr, type_errors)
      annotation = decl["type_annotation"]
      return unless annotation.is_a?(Hash) && annotation.fetch("name", nil) == "OLAPPoint"

      expected = type_ir(annotation)
      actual_node = typed_expr.fetch("semantic_node", nil)
      return unless actual_node

      measure = expected.fetch("params", []).fetch(0, type_ir("Unknown"))
      if type_display(measure) != actual_node.dig("result_type", "measure")
        type_errors << oof("OOF-TY0", "OLAPPoint measure expected #{type_display(measure)}, got #{actual_node.dig("result_type", "measure")}", decl.fetch("name"))
      end
      dims = dims_from_type(expected)
      actual_dims = actual_node.dig("result_type", "dims_record", "dims") || {}
      dims.each do |dim, expected_type|
        actual_type = actual_dims[dim]
        next if actual_type.nil? || type_display(expected_type) == actual_type

        type_errors << oof("OOF-O5", "OLAPPoint dimension '#{dim}' expected #{type_display(expected_type)}, got #{actual_type}", decl.fetch("name"))
      end
    end

    def dims_from_type(type)
      dims_record = type.fetch("params", []).find { |param| param.is_a?(Hash) && (param.fetch("kind", nil) == "dims_record" || param.fetch("name", nil) == "DimsRecord") }
      return {} unless dims_record

      dims_record.fetch("dims", {}).transform_values { |dim_type| type_ir(dim_type) }
    end

    def olap_access_node(node_name, olap_decl, typed_slices)
      {
        "kind" => "olap_access_node",
        "name" => node_name,
        "olap_ref" => olap_decl.fetch("name"),
        "slices" => typed_slices.map do |slice|
          {
            "dim" => slice.fetch("dim"),
            "value_ref" => slice.fetch("value_ref"),
            "value_type" => type_display(slice.fetch("value").fetch("resolved_type"))
          }
        end,
        "operation" => "point",
        "result_type" => {
          "constructor" => "OLAPPoint",
          "measure" => type_display(olap_decl.fetch("measure_type")),
          "dims_record" => {
            "kind" => "dims_record",
            "dims" => olap_decl.fetch("dimensions").transform_values { |type| type_display(type) }
          }
        },
        "resolved_type" => type_display(olap_decl.fetch("measure_type"))
      }
    end

    def slice_value_ref(expr)
      expr.fetch("kind") == "ref" ? expr.fetch("name") : nil
    end

    def explicit_scatter_gather?(args)
      args.any? { |arg| arg.fetch("kind", nil) == "symbol" && arg.fetch("value") == "scatter_gather" }
    end

    def same_type?(expected, actual)
      type_display(expected) == type_display(actual)
    end

    def type_display(type)
      return type.to_s unless type.is_a?(Hash)

      params = type.fetch("params", [])
      return type.fetch("name") if params.empty?

      rendered = params.map { |param| param.is_a?(Hash) ? type_display(param) : param.to_s }.join(",")
      "#{type.fetch("name")}[#{rendered}]"
    end

    def type_name(type)
      type.fetch("name")
    end

    def normalize_type(type)
      type.is_a?(Hash) ? type.fetch("name") : type.to_s
    end

    def literal_type(name)
      {
        "Integer" => "int",
        "Float" => "float",
        "String" => "string",
        "Bool" => "bool",
        "Nil" => "nil"
      }.fetch(name, name.downcase)
    end

    def unknown?(*types)
      types.any? { |type| type_name(type) == "Unknown" }
    end

    def type_mismatch(expected, actual, node)
      oof("OOF-TY0", "Type mismatch: expected #{type_name(expected)}, got #{type_name(actual)}", node)
    end

    def oof(rule, message, node_name)
      { "rule" => rule, "message" => message, "node" => node_name, "line" => nil }
    end

    def oof_alias(rule, message, node_name, aliases)
      oof(rule, message, node_name).merge("aliases" => aliases)
    end

    def rule_present?(errors, rule)
      errors.any? { |entry| entry.fetch("rule") == rule }
    end

    def blocking_rule_present?(errors)
      %w[OOF-P1 OOF-CE4 OOF-OS2 OOF-H1 OOF-BT1 OOF-BT2 OOF-BT3 OOF-BT4 OOF-TM1 OOF-TM3 OOF-TM4 OOF-TM5 OOF-TM6 OOF-S3 OOF-O3 OOF-O4 OOF-O5 OOF-IV3].any? { |rule| rule_present?(errors, rule) }
    end

    # OOF-IV helpers -------------------------------------------------------

    # TC-INV-1: resolve predicate_ref, check Bool type.
    # TC-INV-2: validate overridable_with semantics.
    # TC-INV-3: compute output_effect and record for output propagation.
    def check_invariant(decl, symbol_types, type_errors, invariant_effects)
      predicate_ref = decl.fetch("predicate_ref", nil)
      severity = decl.fetch("severity", "error")
      name = decl.fetch("name")

      # TC-INV-1: predicate must resolve to Bool
      if predicate_ref
        pred_type = symbol_types.fetch(predicate_ref, type_ir("Unknown"))
        unless type_name(pred_type) == "Bool" || type_name(pred_type) == "Unknown"
          type_errors << oof("OOF-IV3", "invariant predicate must be Bool, got #{type_name(pred_type)}", name)
        end
      end

      # TC-INV-2: overridable_with on :error is OOF-I4 (dynamic/inferred case; parser catches static)
      overridable_with = decl.fetch("overridable_with", nil)
      if overridable_with && severity == "error"
        type_errors << oof("OOF-I4", ":error invariants cannot be overridden", name)
      end

      # TC-INV-3: record output effect for TINV-4 propagation
      effect = invariant_output_effect(severity)
      invariant_effects << { "name" => name, "effect" => effect } if %w[warns uncertain metric].include?(effect)
    end

    # Typed node for an invariant declaration.
    def typed_decl_invariant(decl, symbol_types)
      predicate_ref = decl.fetch("predicate_ref", nil)
      pred_type = predicate_ref ? symbol_types.fetch(predicate_ref, type_ir("Unknown")) : type_ir("Unknown")
      output_effect = invariant_output_effect(decl.fetch("severity", "error"))
      result = {
        "decl_id"          => decl.fetch("decl_id"),
        "kind"             => "invariant",
        "name"             => decl.fetch("name"),
        "fragment_class"   => decl.fetch("fragment_class"),
        "predicate_ref"    => predicate_ref,
        "predicate_type"   => pred_type,
        "severity"         => decl.fetch("severity", "error"),
        "label"            => decl.fetch("label", nil),
        "message"          => decl.fetch("message", nil),
        "overridable_with" => decl.fetch("overridable_with", nil),
        "output_effect"    => output_effect,
        "type"             => type_ir("Bool"),
        "deps"             => predicate_ref ? [predicate_ref] : []
      }
      result["source_span"] = decl.fetch("source_span") if decl.key?("source_span")
      result["source_metadata"] = decl.fetch("source_metadata") if decl.key?("source_metadata")
      result["threshold"] = decl.fetch("threshold") if decl.key?("threshold")
      result["threshold_ms"] = decl.fetch("threshold_ms") if decl.key?("threshold_ms")
      result
    end

    # Typed output decl with invariant effect propagation (TINV-4).
    def typed_decl_output(decl, type, invariant_effects)
      result = {
        "decl_id"        => decl.fetch("decl_id"),
        "kind"           => "output",
        "name"           => decl.fetch("name"),
        "fragment_class" => decl.fetch("fragment_class"),
        "type"           => type,
        "deps"           => decl.fetch("deps")
      }
      warnings_from  = invariant_effects.select { |e| e["effect"] == "warns" }.map { |e| e["name"] }
      uncertain_from = invariant_effects.select { |e| e["effect"] == "uncertain" }.map { |e| e["name"] }
      metrics_from   = invariant_effects.select { |e| e["effect"] == "metric" }.map { |e| e["name"] }
      result["warnings_from"]  = warnings_from  unless warnings_from.empty?
      result["uncertain_from"] = uncertain_from unless uncertain_from.empty?
      result["metrics_from"]   = metrics_from   unless metrics_from.empty?
      result
    end

    # Maps severity to the output_effect string (per PROP-025 §3 / spec track Part 3).
    def invariant_output_effect(severity)
      case severity
      when "error"  then "blocks"
      when "warn"   then "warns"
      when "soft"   then "uncertain"
      when "metric" then "metric"
      else "blocks"
      end
    end

    # OOF-S3 helpers -------------------------------------------------------

    # Collect the names of all stream-kind symbols in the classified contract.
    def stream_symbol_names(classified_contract)
      classified_contract.fetch("symbols", []).filter_map do |sym|
        sym.fetch("name") if sym.fetch("kind") == "stream"
      end.to_set
    end

    # Walk the fold_stream accumulator lambda body and emit OOF-S3 for any
    # ref that names a stream symbol (ESCAPE construct inside CORE-required fn).
    def check_fold_stream_body(decl, stream_symbols, type_errors)
      return if stream_symbols.empty?
      return unless decl.fetch("expr", nil)&.fetch("kind", nil) == "call"

      call = decl.fetch("expr")
      lambda_arg = call.fetch("args", []).find { |arg| arg.fetch("kind", nil) == "lambda" }
      return unless lambda_arg

      body = lambda_arg.fetch("body", nil)
      return unless body

      lambda_params = lambda_arg.fetch("params", []).map(&:to_s).to_set
      escape_refs = collect_escape_refs(body, stream_symbols, lambda_params)
      escape_refs.each do |ref_name|
        type_errors << oof(
          "OOF-S3",
          "fold_stream accumulator must be CORE - found ESCAPE: #{ref_name}",
          decl.fetch("name")
        )
      end
    end

    # Recursively collect ref-names from the body AST that are stream symbols
    # but NOT lambda parameters (those shadow the outer stream names).
    def collect_escape_refs(node, stream_symbols, lambda_params)
      return [] unless node.is_a?(Hash)

      case node.fetch("kind", nil)
      when "ref"
        name = node.fetch("name")
        stream_symbols.include?(name) && !lambda_params.include?(name) ? [name] : []
      when "lambda"
        # Nested lambda: extend lambda_params with inner params to avoid false positives
        inner_params = lambda_params + node.fetch("params", []).map(&:to_s)
        collect_escape_refs(node.fetch("body", {}), stream_symbols, inner_params)
      when "binary_op"
        collect_escape_refs(node.fetch("left", {}), stream_symbols, lambda_params) +
          collect_escape_refs(node.fetch("right", {}), stream_symbols, lambda_params)
      when "call"
        node.fetch("args", []).flat_map { |arg| collect_escape_refs(arg, stream_symbols, lambda_params) } +
          collect_escape_refs(node.fetch("object", {}), stream_symbols, lambda_params)
      when "field_access"
        collect_escape_refs(node.fetch("object", {}), stream_symbols, lambda_params)
      else
        # Walk all Hash values for any other node kinds
        node.values.flat_map { |v| v.is_a?(Hash) ? collect_escape_refs(v, stream_symbols, lambda_params) : [] }
      end.uniq
    end

    # Determine the fold_stream result type from the init literal or annotation.
    # Returns Unknown if the init expression does not carry a type_tag.
    def fold_stream_result_type(decl)
      expr = decl.fetch("expr", nil)
      return type_ir("Unknown") unless expr&.fetch("kind", nil) == "call"

      args = expr.fetch("args", [])
      init_arg = args[1] # args[0]=stream_ref, args[1]=init, args[2]=lambda
      return type_ir("Unknown") unless init_arg&.fetch("kind", nil) == "literal"

      type_ir(init_arg.fetch("type_tag", "Unknown"))
    end

    def dedupe_errors(errors)
      errors.uniq { |entry| [entry.fetch("rule"), entry.fetch("message"), entry.fetch("node"), entry.fetch("line")] }
    end
  end

  Typechecker = TypeChecker
end
