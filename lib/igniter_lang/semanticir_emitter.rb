# frozen_string_literal: true

require "digest"
require "json"

module IgniterLang
  class SemanticIREmitter
    FORMAT_VERSION = "0.1.0"

    def emit(parsed_program, sample_input:)
      @callables = {}
      @types = type_shapes(parsed_program)
      semantic_contracts = parsed_program.fetch("contracts").map do |contract|
        emit_contract(parsed_program, contract, sample_input)
      end
      diagnostics = dedupe_oofs(semantic_contracts.flat_map { |contract| contract.fetch("diagnostics") })
      semantic_ir = diagnostics.empty? ? semantic_ir_program(parsed_program, semantic_contracts) : nil

      {
        "semantic_ir" => semantic_ir,
        "compilation_report" => compilation_report(parsed_program, diagnostics, semantic_ir)
      }
    end

    alias compile emit

    def emit_typed(typed_program)
      @callables = {}
      diagnostics = typed_program.fetch("type_errors", [])
      semantic_ir = diagnostics.empty? ? typed_semantic_ir_program(typed_program) : nil

      {
        "semantic_ir" => semantic_ir,
        "compilation_report" => typed_compilation_report(typed_program, diagnostics, semantic_ir)
      }
    end

    private

    def semantic_ir_program(parsed_program, contracts)
      report_id = compilation_report_id(parsed_program)
      result = {
        "kind" => "semantic_ir_program",
        "format_version" => FORMAT_VERSION,
        "option_carrier" => "first_class_v1",
        "program_id" => program_id(parsed_program),
        "grammar_version" => parsed_program.fetch("grammar_version"),
        "source_hash" => parsed_program.fetch("source_hash"),
        "source_path" => source_path(parsed_program),
        "module" => parsed_program.fetch("module"),
        "compilation_report_ref" => report_id,
        "contracts" => contracts.map { |contract| contract.reject { |key, _value| key == "diagnostics" } }
      }
      declarations = semantic_type_declarations(@types)
      result["type_declarations"] = declarations unless declarations.empty?
      result
    end

    def compilation_report(parsed_program, diagnostics, semantic_ir)
      ok = diagnostics.empty?
      {
        "kind" => "compilation_report",
        "format_version" => FORMAT_VERSION,
        "program_id" => compilation_report_id(parsed_program),
        "grammar_version" => parsed_program.fetch("grammar_version"),
        "source_hash" => parsed_program.fetch("source_hash"),
        "source_path" => source_path(parsed_program),
        "pass_result" => ok ? "ok" : "oof",
        "stages" => {
          "parse" => "ok",
          "classify" => ok ? "ok" : "oof",
          "typecheck" => ok ? "ok" : "skipped",
          "emit" => ok ? "ok" : "skipped"
        },
        "diagnostics" => diagnostics.map { |entry| diagnostic(entry) },
        "semantic_ir_ref" => semantic_ir&.fetch("program_id")
      }
    end

    def typed_semantic_ir_program(typed_program)
      report_id = typed_compilation_report_id(typed_program)
      result = {
        "kind" => "semantic_ir_program",
        "format_version" => FORMAT_VERSION,
        "option_carrier" => "first_class_v1",
        "program_id" => typed_program_id(typed_program),
        "grammar_version" => typed_program.fetch("grammar_version"),
        "source_hash" => typed_program.fetch("source_hash"),
        "source_path" => source_path(typed_program),
        "module" => typed_program.fetch("module"),
        "compilation_report_ref" => report_id,
        "contracts" => typed_program.fetch("contracts").map { |contract| typed_contract_ir(contract) }
      }
      # LAB-IGNITER-STREAM-ARTIFACT-EXECUTABILITY-P2 (A law): the callable
      # registry is present at the SIR root ONLY when the program contains
      # fold_stream nodes (byte-compat for every non-stream program). Key =
      # fn_ref, value = {"kind"=>"callable_v1","params"=>…,"body"=>…} in the
      # shared expr grammar; populated during fold_stream_node emission.
      unless @callables.nil? || @callables.empty?
        result["callables"] = @callables.keys.sort.to_h { |ref| [ref, @callables.fetch(ref)] }
      end
      # LANG-APP-LOCAL-DEF-CALL-CANON-ADOPTION-P2 (PROP-051 §1.7): top-level
      # `functions` array (present only when the program declares defs) — the
      # typed registry entries lowered to function_ir nodes carrying the
      # reserved `user.<module>.<name>` identity.
      typed_functions = typed_program.fetch("functions", [])
      result["functions"] = typed_functions.map { |fn| function_ir(fn) } unless typed_functions.empty?
      assumptions = typed_assumption_registry(typed_program)
      result["assumption_registry"] = assumptions unless assumptions.empty?
      result["olap_points"] = typed_program.fetch("olap_points") if typed_program.key?("olap_points")
      invariants = typed_program_invariants(result.fetch("contracts"))
      result["invariants"] = invariants unless invariants.empty?
      # PROP-044 P6: emit variant declarations when present
      variant_env = typed_program.fetch("variant_env", {})
      result["variant_declarations"] = semantic_variant_declarations(variant_env) unless variant_env.empty?
      declarations = semantic_type_declarations(
        typed_program.fetch("declared_type_env", typed_program.fetch("type_env", {}))
      )
      result["type_declarations"] = declarations unless declarations.empty?
      # PROP-045: emit module-level intent_text when present
      module_intent = typed_program.fetch("intent_text", nil)
      result["intent_text"] = module_intent if module_intent
      entrypoint = semantic_entrypoint(typed_program, result.fetch("contracts"))
      result["entrypoint"] = entrypoint if entrypoint
      result
    end

    # Typed host projection needs the complete, deterministic schema of named
    # Records reached from contract ports.  Ports retain their full type trees;
    # named declarations live once at program scope and are resolved recursively
    # by the shared runtime codec.
    def semantic_type_declarations(type_env)
      type_env.keys.sort.map do |name|
        fields = type_env.fetch(name)
        {
          "kind" => "type_decl",
          "name" => name,
          "fields" => fields.keys.sort.map do |field_name|
            field_type = fields.fetch(field_name)
            {
              "name" => field_name,
              "type" => normalize_semantic_type_ir(
                field_type.is_a?(Hash) ? field_type : type_ir(field_type)
              )
            }
          end
        }
      end
    end

    def semantic_entrypoint(typed_program, contracts)
      entrypoint = typed_program.fetch("entrypoint", nil)
      return nil unless entrypoint

      contract = contracts.find do |contract_ir|
        contract_ir.fetch("contract_name") == entrypoint.fetch("resolved_contract")
      end
      return entrypoint unless contract

      entrypoint.merge(
        "kind" => "entrypoint_decl",
        "contract_ref" => contract.fetch("contract_ref")
      )
    end

    def typed_compilation_report(typed_program, diagnostics, semantic_ir)
      ok = diagnostics.empty?
      report = {
        "kind" => "compilation_report",
        "format_version" => FORMAT_VERSION,
        "program_id" => typed_compilation_report_id(typed_program),
        "grammar_version" => typed_program.fetch("grammar_version"),
        "source_hash" => typed_program.fetch("source_hash"),
        "source_path" => source_path(typed_program),
        "pass_result" => ok ? "ok" : "oof",
        "stages" => {
          "parse" => "ok",
          "classify" => "ok",
          "typecheck" => ok ? "ok" : "oof",
          "emit" => ok ? "ok" : "skipped"
        },
        "diagnostics" => diagnostics.map { |entry| diagnostic(entry) },
        "semantic_ir_ref" => semantic_ir&.fetch("program_id")
      }
      coverage = typed_invariant_coverage(semantic_ir)
      report["invariant_coverage"] = coverage unless coverage.empty?
      report
    end

    def program_id(parsed_program)
      "semanticir/#{parsed_program.fetch("source_hash").delete_prefix("sha256:")[0, 16]}"
    end

    def compilation_report_id(parsed_program)
      "compilation_report/#{parsed_program.fetch("source_hash").delete_prefix("sha256:")[0, 16]}"
    end

    def typed_program_id(typed_program)
      program_id(typed_program)
    end

    def typed_compilation_report_id(typed_program)
      compilation_report_id(typed_program)
    end

    def source_path(parsed_program)
      parsed_program.fetch("source_path").delete_prefix("igniter-lang/")
    end

    def typed_contract_ir(contract)
      contract_ir = {
        "kind" => "contract_ir",
        "option_carrier" => "first_class_v1",
        "contract_ref" => nil,
        "contract_name" => contract.fetch("name"),
        "modifier" => contract.fetch("modifier", "pure"),
        "specialization_of" => nil,
        "type_args" => {},
        "fragment_class" => contract.fetch("fragment_class"),
        "inputs" => typed_ports(contract, "input"),
        "outputs" => typed_ports(contract, "output"),
        "nodes" => typed_nodes(contract),
        "escape_boundaries" => typed_escape_boundaries(contract)
      }
      # LANG-EFFECT-SURFACE-RUNTIME-BRIDGE-P3: emit effect_surface_v1 for IO effect contracts
      effect_surface = io_effect_surface_v1(contract)
      contract_ir["effect_surface"] = effect_surface if effect_surface
      # PROP-033/040: emit profile_binding and profile_authority when via_profile is present
      via_profile       = contract.fetch("via_profile", nil)
      profile_authority = contract.fetch("profile_authority", nil)
      contract_ir["profile_binding"]   = via_profile       if via_profile
      contract_ir["profile_authority"] = profile_authority if profile_authority
      # PROP-045: emit intent_text when present (metadata only; not in behavior digest)
      intent_text = contract.fetch("intent_text", nil)
      contract_ir["intent_text"] = intent_text if intent_text
      assumption_refs = contract.fetch("assumption_refs", [])
      contract_ir["assumption_refs"] = assumption_refs unless assumption_refs.empty?
      # LANG-TYPED-CONTRACT-REF-PROP-P3: emit typed contract reference declarations
      contract_ref_decls = contract.fetch("contract_ref_declarations", [])
      unless contract_ref_decls.empty?
        contract_ir["contract_refs"] = contract_ref_decls.map do |decl|
          resolved_ref = decl["resolved_ref"]
          ref = {
            "contract_name"     => resolved_ref ? resolved_ref.fetch("contract_name") : decl.fetch("target"),
            "resolution_status" => decl.fetch("resolution_status", "unresolved")
          }
          ref["resolution_kind"] = decl["resolution_kind"] if decl.key?("resolution_kind")
          if (resolved = resolved_ref)
            ref["module_name"]   = resolved["module_name"]
            ref["modifier"]      = resolved["modifier"]
            ref["input_count"]   = resolved["input_count"]
            ref["input_names"]   = resolved["input_names"]
            ref["output_names"]  = resolved["output_names"]
          end
          ref
        end
      end
      # PROP-042 T3 / PROP-041 T2 / PROP-039 OOF-R3: emit termination evidence.
      # Dispatch priority (mutually exclusive — only one fires per contract):
      #   T3 numeric_measure_v0  — set by handle_t3_variant (PROP-042)
      #   T2 structural_size_v1  — set by handle_t2_variant (PROP-041)
      #   T1 syntactic_v0        — clean simple-identifier decreases (PROP-039)
      # T2 and T1 are structural evidence / syntactic evidence with trust metadata.
      # T3 is numeric evidence with trust metadata.
      # None of these constitute a full termination proof.
      decreases_variant    = contract.fetch("decreases_variant", nil)
      decreases_variant_t2 = contract.fetch("decreases_variant_t2", nil)
      decreases_variant_t3 = contract.fetch("decreases_variant_t3", nil)  # PROP-042 T3
      if contract_ir["modifier"] == "recursive" && decreases_variant_t3
        # PROP-042 T3: numeric_measure_v0 — numeric measure evidence with stdlib_numeric_certified trust
        evidence = contract.fetch("numeric_measure_evidence", {})
        contract_ir["termination"] = {
          "decreases"       => decreases_variant_t3,
          "variant_check"   => "numeric_measure_v0",
          "numeric_measure" => {
            "fn"     => evidence.fetch("qualified_name"),
            "arg"    => evidence.fetch("arg"),
            "trust"  => evidence.fetch("trust"),
            "source" => evidence.fetch("source")
          }
        }
      elsif contract_ir["modifier"] == "recursive" && decreases_variant_t2
        # PROP-041 T2: structural_size_v1 — unchanged
        evidence = contract.fetch("size_relation_evidence", {})
        contract_ir["termination"] = {
          "decreases"     => decreases_variant_t2,
          "variant_check" => "structural_size_v1",
          "size_relation" => {
            "accessor" => decreases_variant_t2.split(".", 2).last,
            "trust"    => evidence.fetch("trust", "user_assumed"),
            "source"   => evidence.fetch("source", "unknown")
          }
        }
      elsif contract_ir["modifier"] == "recursive" && decreases_variant
        # T1: syntactic_v0 — unchanged
        contract_ir["termination"] = {
          "decreases"     => decreases_variant,
          "variant_check" => "syntactic_v0"
        }
      end
      # LANG-EMITTER-MAX-STEPS-P1: the declared static `max_steps` budget reaches
      # the artifact. Joins the existing termination evidence when present (T1/T2/
      # T3); else creates a minimal termination object (the recursive+decreases-
      # fuel and fuel_bounded cases emit no decreases evidence by design). The VM
      # fuel loop reads termination.max_steps; its default applies otherwise.
      max_steps = contract.fetch("max_steps", nil)
      (contract_ir["termination"] ||= {})["max_steps"] = max_steps if max_steps
      contract_ir["contract_ref"] = contract_ref(contract_ir)
      contract_ir
    end

    def typed_ports(contract, kind)
      contract.fetch("declarations").select { |decl| decl.fetch("kind") == kind }.map do |decl|
        port = {
          "name" => decl.fetch("name"),
          "type" => normalize_semantic_type_ir(decl.fetch("type")),
          "lifecycle" => decl.fetch("lifecycle", kind == "input" ? "local" : "session")
        }
        if kind == "output"
          port["warnings_from"] = decl.fetch("warnings_from") if decl.key?("warnings_from")
          port["uncertain_from"] = decl.fetch("uncertain_from") if decl.key?("uncertain_from")
          port["metrics_from"] = decl.fetch("metrics_from") if decl.key?("metrics_from")
          port["evidence"] = decl.fetch("evidence") if decl.key?("evidence")  # PROP-034
        end
        port
      end
    end

    def typed_nodes(contract)
      declarations = contract.fetch("declarations")
      business_nodes = contract.fetch("declarations").filter_map do |decl|
        next decl.fetch("semantic_node") if decl.key?("semantic_node")

        case decl.fetch("kind")
        when "stream"
          stream_input_node(decl, declarations)
        when "window"
          window_decl_node(decl)
        when "fold_stream"
          fold_stream_node(decl, declarations)
        when "uses_assumptions"
          assumption_ref_node(decl)
        when "uses_contract"
          nil  # LANG-TYPED-CONTRACT-REF-PROP-P3: metadata only — not emitted as a runtime node
        when "invariant"
          invariant_node(decl)
        when "read"
          temporal_input_node(decl) if decl.fetch("node_fragment_class", nil) == "temporal"
        when "compute"
          temporal_access_node(decl) ||
          {
            "kind" => "compute",
            "name" => decl.fetch("name"),
            "expr" => semantic_expr(decl.fetch("expr")),
            "type" => decl.fetch("type"),
            "deps" => decl.fetch("deps", []),
            "fragment" => decl.fetch("fragment_class")
          }
        when "for_loop"
          # PROP-039 gate 5: FiniteLoop → loop_node, termination by collection exhaustion
          loop_node(decl, "finite", "collection_exhaustion")
        when "budgeted_loop"
          # PROP-039 gate 5: BudgetedLocalLoop → loop_node, termination by budget exhaustion
          loop_node(decl, "budgeted", "budget_exhaustion")
        end
      end
      temporal_stores = temporal_history_stores(declarations)
      business_nodes.map! { |node| lower_nested_history_reads(node, temporal_stores) }
      [option_carrier_guard_node] + business_nodes
    end

    # A top-level history_at remains the existing temporal_access_node owned by
    # typed_nodes. Nested authored reads cannot use that contract-node lane, so
    # lower only the exact history_at(read_ref, as_of_ref) shape to the VM's
    # existing inline temporal_read expression. The store template comes from
    # the same contract-local read declaration; no runtime carrier/store
    # inference is introduced.
    def temporal_history_stores(declarations)
      declarations.each_with_object({}) do |decl, stores|
        next unless decl.fetch("kind", nil) == "read"
        next unless decl.fetch("required_capability", nil) == "history_read"
        next unless decl.fetch("temporal_axis", nil) == "valid_time"

        store_ref = decl.fetch("from", nil)
        stores[decl.fetch("name")] = store_ref if store_ref.is_a?(String)
      end
    end

    def lower_nested_history_reads(value, temporal_stores)
      case value
      when Hash
        temporal_read = nested_history_read_node(value, temporal_stores)
        return temporal_read if temporal_read

        value.transform_values { |child| lower_nested_history_reads(child, temporal_stores) }
      when Array
        value.map { |child| lower_nested_history_reads(child, temporal_stores) }
      else
        value
      end
    end

    def nested_history_read_node(expr, temporal_stores)
      return nil unless expr.fetch("kind", nil) == "call"
      return nil unless expr.fetch("fn", nil) == "history_at"

      args = expr.fetch("args", [])
      return nil unless args.length == 2

      history_ref = ref_name(args[0])
      as_of_ref = ref_name(args[1])
      store_ref = temporal_stores[history_ref]
      resolved_type = expr.fetch("resolved_type", nil)
      return nil unless store_ref && as_of_ref && resolved_type

      {
        "kind" => "temporal_read",
        "source_ref" => history_ref,
        "store_ref" => store_ref,
        "as_of_ref" => as_of_ref,
        "resolved_type" => normalize_semantic_type_ir(resolved_type)
      }
    end

    # The marker is semantic identity; this first executable node is the
    # downgrade fence.  A predecessor compiler/runtime does not know this
    # expression kind and refuses the selected contract before business
    # execution.  The v1 runtime validates exact placement and shape.
    def option_carrier_guard_node
      bool_type = { "name" => "Bool", "params" => [] }
      {
        "kind" => "compute",
        "name" => "__option_carrier_guard_v1",
        "expr" => {
          "kind" => "option_carrier_guard_v1",
          "version" => "first_class_v1",
          "body" => { "kind" => "literal", "value" => true },
          "resolved_type" => bool_type
        },
        "type" => bool_type,
        "deps" => [],
        "fragment" => "core"
      }
    end

    def typed_assumption_registry(typed_program)
      typed_program.fetch("assumption_registry", []).map do |entry|
        {
          "kind" => "assumption_ir",
          "name" => entry.fetch("name"),
          "fields" => entry.fetch("fields", {})
        }.tap do |node|
          node["declared_in_module"] = entry.fetch("declared_in_module") if entry.key?("declared_in_module")
        end
      end
    end

    def assumption_ref_node(decl)
      {
        "kind" => "assumption_ref_node",
        "name" => decl.fetch("name"),
        "assumption_ref" => decl.fetch("name"),
        "type" => decl.fetch("type"),
        "fragment" => decl.fetch("fragment_class", "epistemic")
      }
    end

    def typed_program_invariants(contracts)
      contracts.flat_map do |contract|
        contract.fetch("nodes").select { |node| node.fetch("kind") == "invariant_node" }
      end
    end

    # LANG-APP-LOCAL-DEF-CALL-CANON-ADOPTION-P2 (PROP-051 §1.7): one app-local
    # def as SIR. Keys exactly {kind, name, params, return_type, decreases?,
    # body}; `name` is the emitted identity `user.<module>.<name>`; types are
    # display text; `body` is the right-nested `let` lowering of the block
    # through the SAME `semantic_expr` contracts use (bare statements bind
    # `__seq__`). Rust twin: emit_function_ir (LAB-FUNCTION-SIR-RUNTIME-P1).
    def function_ir(fn)
      node = {
        "kind" => "function_ir",
        "name" => fn.fetch("emitted_name"),
        "params" => fn.fetch("params", []).map do |param|
          {
            "name" => param.fetch("name"),
            "type" => function_type_display(param.fetch("type_annotation", "Unknown"))
          }
        end,
        "return_type" => function_type_display(fn.fetch("return_type", "Unknown"))
      }
      node["decreases"] = fn.fetch("decreases") if fn.key?("decreases")
      node["body"] = function_body_ir(fn.fetch("body", {}))
      node
    end

    # Right-nested let chain over the block: each statement wraps the rest as
    # {kind: "let", name, expr, body}; a bare statement binds `__seq__`; the
    # chain ends in the return expression.
    def function_body_ir(body)
      return_expr = body.fetch("return_expr", nil)
      acc = return_expr ? semantic_expr(return_expr) : nil
      body.fetch("stmts", []).reverse_each do |stmt|
        acc = {
          "kind" => "let",
          "name" => stmt.fetch("name", "__seq__"),
          "expr" => semantic_expr(stmt.fetch("expr", nil)),
          "body" => acc
        }
      end
      acc
    end

    # Display text for a source type annotation ("Name" or "Name[P,...]") —
    # twin of the Rust emitter's semantic_type_display.
    def function_type_display(annotation)
      return annotation.to_s unless annotation.is_a?(Hash)

      name = annotation.fetch("name", "Unknown")
      params = annotation.fetch("params", [])
      return name if params.empty?

      "#{name}[#{params.map { |param| function_type_display(param) }.join(",")}]"
    end

    def semantic_expr(expr)
      case expr
      when Hash
        if expr.fetch("kind", nil) == "if_expr"
          semantic_if_expr(expr)
        # PROP-044 P6: variant_construct → typed variant_construct node
        elsif expr.fetch("kind", nil) == "variant_construct"
          semantic_variant_construct(expr)
        # LANG-SECRET-REF-NATIVE-P2: secret_ref → dedicated sealed SIR node (name only).
        elsif expr.fetch("kind", nil) == "secret_ref"
          {
            "kind"          => "secret_ref",
            "name"          => expr.fetch("name"),
            "resolved_type" => expr.fetch("resolved_type", { "name" => "SecretRef", "params" => [] }),
            "sealed"        => true
          }
        # LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2: source constructors and
        # optional-field normalization converge on one nominal SIR identity.
        elsif expr.fetch("kind", nil) == "option_value_construct"
          semantic_option_value_construct(expr)
        # PROP-044 P6: match_expr → typed match_node (renamed to avoid confusion with parse AST)
        elsif expr.fetch("kind", nil) == "match_expr"
          semantic_match_node(expr)
        # PROP-039 gate 5: recur() call → recur_call sub-expression node
        elsif expr.fetch("kind", nil) == "call" && expr.fetch("fn", nil) == "recur"
          {
            "kind"        => "recur_call",
            "args"        => (expr.fetch("args", []) || []).map { |a| semantic_expr(a) },
            "return_type" => (expr.fetch("resolved_type", {}) || {}).fetch("name", "Unknown")
          }
        elsif fold_call_expr?(expr)
          fold_aggregate_node(expr) || semantic_generic_expr(expr)
        else
          semantic_generic_expr(expr)
        end
      when Array
        expr.map { |item| semantic_expr(item) }
      else
        expr
      end
    end

    def semantic_generic_expr(expr)
      expr.each_with_object({}) do |(key, value), result|
        next if key == "deps"

        result[key] = semantic_expr(value)
      end
    end

    def fold_call_expr?(expr)
      expr.fetch("kind", nil) == "call" &&
        ["fold", "stdlib.collection.fold"].include?(expr.fetch("fn", nil))
    end

    def fold_aggregate_node(expr)
      args = expr.fetch("args", [])
      return nil unless args.length >= 3

      lambda_expr = args[2]
      return nil unless lambda_expr.is_a?(Hash)

      {
        "kind" => "map_reduce_aggregate",
        "source" => semantic_expr(args[0]),
        "pipeline" => [fold_node(args[1], lambda_expr)]
      }
    end

    def fold_node(init_expr, lambda_expr)
      params = lambda_expr.fetch("params", [])
      {
        "kind" => "fold",
        "param_acc" => params.fetch(0, "acc"),
        "param_val" => params.fetch(1, "x"),
        "init" => semantic_expr(init_expr),
        "body" => semantic_expr(lambda_expr.fetch("body", nil))
      }
    end

    # Lower a TypeChecker if_expr (cond/then/else with branch wrappers) to the
    # flat SemanticIR shape (condition/then_branch/else_branch, no branch wrapper).
    # Recursive: any nested if_expr in condition, then_branch, or else_branch
    # is lowered by the same convention via semantic_expr.
    def semantic_if_expr(expr)
      then_expr = expr.fetch("then", {}).fetch("expr", nil)
      else_expr = expr.fetch("else", {}).fetch("expr", nil)
      {
        "kind"          => "if_expr",
        "condition"     => semantic_expr(expr.fetch("cond")),
        "then_branch"   => semantic_expr(then_expr),
        "else_branch"   => semantic_expr(else_expr),
        "resolved_type" => expr.fetch("resolved_type")
      }
    end

    # PROP-044 P6: convert variant_env (3-level hash) to variant_decl node array.
    def semantic_variant_declarations(variant_env)
      variant_env.map do |variant_name, arms|
        {
          "kind" => "variant_decl",
          "name" => variant_name,
          "arms" => arms.map do |arm_name, fields|
            {
              "name"   => arm_name,
              "fields" => fields.map { |fname, type_ir| {"name" => fname, "type" => type_ir} }
            }
          end
        }
      end
    end

    # PROP-044 P6: lower a TypeChecker variant_construct node to SemanticIR shape.
    def semantic_variant_construct(expr)
      node = {
        "kind"          => "variant_construct",
        "arm"           => expr.fetch("arm"),
        "variant"       => expr.fetch("variant"),
        "fields"        => expr.fetch("typed_fields", {}).transform_values { |f| semantic_expr(f) },
        "resolved_type" => expr.fetch("resolved_type")
      }
      # LANG-SUMTYPE-CONSTRUCT-MATCH-P3: sealed-only marker; absent for user variants
      # so their SIR byte shape is unchanged.
      node["sealed"] = true if expr.fetch("sealed", false)
      node
    end

    # Canonical v1 Option construction, parity-locked with the Rust compiler:
    #   { "kind": "option_value_construct", "arm": "Some"|"None",
    #     "value": <expr — Some only>,
    #     "resolved_type": { "name": "Option", "params": [<T ir>] } }
    def semantic_option_value_construct(expr)
      node = {
        "kind" => "option_value_construct",
        "arm" => expr.fetch("arm")
      }
      node["value"] = semantic_expr(expr.fetch("value")) if expr.key?("value")
      node["resolved_type"] = normalize_semantic_type_ir(expr.fetch("resolved_type"))
      node
    end

    # PROP-044 P6: lower a TypeChecker match_expr node to SemanticIR match_node shape.
    def semantic_match_node(expr)
      subject_type = expr.fetch("subject_type")
      subject_type_name = subject_type.is_a?(Hash) ? subject_type.fetch("name", nil) : subject_type
      node = {
        # LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2: an Option subject has a
        # dedicated semantic owner.  Result and user variants retain the generic
        # match_node path and carrier unchanged.
        "kind"          => subject_type_name == "Option" ? "option_match" : "match_node",
        "subject"       => semantic_expr(expr.fetch("subject")),
        "subject_type"  => normalize_semantic_type_ir(subject_type),
        "arms"          => expr.fetch("arms", []).map { |arm| semantic_match_arm(arm) },
        "exhaustive"    => expr.fetch("exhaustive", false),
        "has_wildcard"  => expr.fetch("has_wildcard", false),
        "resolved_type" => normalize_semantic_type_ir(expr.fetch("resolved_type"))
      }
      # LANG-SUMTYPE-CONSTRUCT-MATCH-P3: sealed-only marker (Option/Result subjects).
      node["sealed"] = true if expr.fetch("sealed", false)
      node
    end

    def semantic_match_arm(arm)
      body = arm.fetch("body")
      {
        "pattern"       => arm.fetch("pattern"),
        "body"          => semantic_expr(body),
        "resolved_type" => normalize_semantic_type_ir(body.fetch("resolved_type"))
      }
    end

    # Classifier/typechecker type refs may retain parser-local `kind: type_ref`
    # metadata. SemanticIR has one normalized recursive type-tree identity
    # shared by ports, named Record declarations, constructors, and matches.
    def normalize_semantic_type_ir(type)
      return type unless type.is_a?(Hash)

      type.each_with_object({}) do |(key, value), normalized|
        next if key == "kind" && value == "type_ref"

        normalized[key] =
          case value
          when Hash
            normalize_semantic_type_ir(value)
          when Array
            value.map { |item| normalize_semantic_type_ir(item) }
          else
            value
          end
      end
    end

    def typed_invariant_coverage(semantic_ir)
      return [] unless semantic_ir

      typed_program_invariants(semantic_ir.fetch("contracts")).map do |node|
        coverage = {
          "name" => node.fetch("name"),
          "severity" => node.fetch("severity"),
          "label" => node.fetch("label", nil),
          "message" => node.fetch("message", nil),
          "output_policy" => node.fetch("severity") == "error" ? "blocking" : "non_blocking",
          "output_effect" => node.fetch("output_effect")
        }
        coverage["source_metadata"] = node.fetch("source_metadata") if node.key?("source_metadata")
        coverage
      end
    end

    def typed_escape_boundaries(contract)
      temporal_caps = contract.fetch("declarations")
        .select { |decl| decl.fetch("node_fragment_class", nil) == "temporal" }
        .map { |decl| decl.fetch("required_capability") }
        .uniq
        .sort
      boundaries = temporal_caps.map do |capability|
        {
          "name" => capability,
          "required_caps" => [capability],
          "produces" => [capability == "bihistory_read" ? "bihistory_access_observation" : "history_access_observation"]
        }
      end
      unless contract.fetch("declarations").any? { |decl| decl.fetch("kind") == "stream" }
        return boundaries + io_capability_escape_boundaries(contract)
      end

      boundaries + [
        {
          "name" => "stream_input",
          "required_caps" => ["stream_input"],
          "produces" => ["stream_window_observation"]
        }
      ] + io_capability_escape_boundaries(contract)
    end

    def io_effect_surface_v1(contract)
      modifier = contract.fetch("modifier", "pure")
      decls    = contract.fetch("declarations", [])
      # PROP-050 / LAB-EFFECT-CALL-V0-P3 (S1): invoke declarations justify an
      # effect_surface_v1 on an `observed` caller too (the v0 runtime fence is
      # observed->observed). ADDITIVE: contracts without invokes keep the exact
      # prior surface (or none) — zero golden churn for existing programs.
      invoke_decls = decls.select { |d| d.fetch("kind") == "invoke" }
      unless %w[effect privileged irreversible].include?(modifier) ||
             (modifier == "observed" && invoke_decls.any?)
        return nil
      end

      cap_decls = decls.select { |d| d.fetch("kind") == "capability" }
      # LANG-EFFECT-SURFACE-RECEIPT-FAILURE-P1: parsed receipt/failure metadata also
      # justifies an effect_surface object even before any capability is declared.
      receipt_decl = decls.find { |d| d.fetch("kind") == "receipt" }
      failure_decl = decls.find { |d| d.fetch("kind") == "failure" }
      # LANG-EFFECT-SURFACE-IDEMPOTENCY-P2: parsed idempotency clause.
      idem_decl = decls.find { |d| d.fetch("kind") == "idempotency" }
      # LANG-EFFECT-SURFACE-AFFECTS-P5: parsed affects clause.
      affects_decl = decls.find { |d| d.fetch("kind") == "affects" }
      # LANG-EFFECT-SURFACE-AUTHORITY-PARSER-P10: parsed authority clause.
      authority_decl = decls.find { |d| d.fetch("kind") == "authority" }
      # LANG-EFFECT-SURFACE-COMPENSATION-P22: parsed compensation decision.
      comp_decl    = decls.find { |d| d.fetch("kind") == "compensation" }
      no_comp_decl = decls.find { |d| d.fetch("kind") == "no_compensation" }
      # LANG-EFFECT-SURFACE-REVERSIBILITY-P25: parsed reversibility scale value.
      rev_decl     = decls.find { |d| d.fetch("kind") == "reversibility" }
      if cap_decls.empty? && receipt_decl.nil? && failure_decl.nil? && idem_decl.nil? &&
         affects_decl.nil? && authority_decl.nil? && comp_decl.nil? && no_comp_decl.nil? &&
         rev_decl.nil? && invoke_decls.empty?
        return nil
      end

      eff_decls = decls.select { |d| d.fetch("kind") == "effect_binding" }
      bindings  = cap_decls.map do |cap|
        cap_name = cap.fetch("name")
        eff      = eff_decls.find { |e| e.fetch("deps", []).include?(cap_name) }
        binding = {
          "capability_name" => cap_name,
          "capability_type" => cap.fetch("type", {}).fetch("name", "IO.Capability"),
          "effect_name"     => eff&.fetch("name")
        }
        # LANG-NETWORK-CAPABILITY-GRAMMAR-P2: the normalized policy object under
        # the declared capability slot. DECLARED intent for a future host binding
        # — `enforcement: "host_required"` is the explicit authority marker
        # (declaration ≠ enforcement; passport authority is unchanged). Key added
        # ONLY for structured IO.NetworkCapability declarations, so every
        # existing program keeps a byte-identical effect_surface.
        if (na = cap["network_attributes"])
          binding["network_capability"] = {
            "kind"            => "network_capability_v1",
            "protocol"        => na.fetch("protocol"),
            "allowed_hosts"   => na.fetch("allowed_hosts"),
            "port_lo"         => na.fetch("port_lo"),
            "port_hi"         => na.fetch("port_hi"),
            "loopback_only"   => na.fetch("loopback_only"),
            "connect_allowed" => na.fetch("connect_allowed"),
            "listen_allowed"  => na.fetch("listen_allowed"),
            "tls_required"    => na.fetch("tls_required"),
            "enforcement"     => "host_required"
          }
        end
        binding
      end

      surface = {
        "kind"                 => "effect_surface_v1",
        "capability_bindings"  => bindings,
        # LANG-EFFECT-SURFACE-AFFECTS-P5: parsed affects clause replaces the former
        # hardcoded constants. Absent clause keeps the documented defaults.
        "affects_scope"        => affects_decl&.fetch("scope", nil) || "external",
        "affects_target"       => affects_decl&.fetch("target", nil) || "IO.Capability",
        # LANG-EFFECT-SURFACE-AUTHORITY-PARSER-P10: parsed DECLARED-INTENT role
        # ident (ratified model F); nil when absent. NOT runtime enforcement.
        "authority_ref"        => authority_decl&.fetch("ref", nil),
        # LANG-EFFECT-SURFACE-IDEMPOTENCY-P2: parsed idempotency clause replaces the
        # former hardcoded "none". Absent clause stays "none" (v0-stub default).
        "idempotency_mode"     => idem_decl&.fetch("mode", "none") || "none",
        "idempotency_key_expr" => idem_decl&.fetch("expr", nil),
        # LANG-EFFECT-SURFACE-COMPENSATION-P22: three-state compensation decision —
        # null (undeclared) ≠ "none" (explicit no_compensation) ≠ "ref"+name.
        # Declaration only: no authority, no host binding, no execution.
        "compensation_mode"    => comp_decl ? "ref" : (no_comp_decl ? "none" : nil),
        "compensation_ref"     => comp_decl&.fetch("contract_ref", nil),
        # LANG-EFFECT-SURFACE-REVERSIBILITY-P25: bare scale value; ABSENT ⇒ null —
        # no default (the scale has none; required-enforcement is a later slice).
        "reversibility"        => rev_decl&.fetch("value", nil),
        # Parsed values (full type_ir) replace the former hardcoded nils.
        "receipt_type"         => receipt_decl&.fetch("type", nil),
        "failure_type"         => failure_decl&.fetch("type", nil)
      }

      # PROP-050 / LAB-EFFECT-CALL-V0-P3 (S1): SIR absorption (packet §5) —
      # ADDITIVE fields, emitted ONLY when the contract has invokes (no golden
      # churn for existing programs; no existing field is mutated). `invokes[]`
      # carries the per-callee absorbed record; `effects` is the ONE flattened
      # list (caller's own effect bindings + each callee's effects tagged with
      # `via_invoke` provenance) that ch11/ch12 policy and audit read.
      if invoke_decls.any?
        surface["invokes"] = invoke_decls.map do |inv|
          {
            "binding"  => inv.fetch("binding", inv.fetch("name", nil)),
            "callee"   => inv.fetch("callee", nil),
            "using"    => inv.fetch("using", []),
            "absorbed" => inv.fetch("absorbed",
              { "effects" => [], "affects" => [], "idempotency_mode" => nil,
                "reversibility" => nil, "receipt_type" => nil,
                "failure_type" => nil, "authority" => nil })
          }
        end
        own_effects = bindings.filter_map do |b|
          next unless b["effect_name"]
          { "name" => b["effect_name"], "capability_ref" => b["capability_name"] }
        end
        via_effects = invoke_decls.flat_map do |inv|
          inv.fetch("effects_flat", []).map do |fe|
            { "name" => fe["name"], "capability_ref" => fe["capability_ref"],
              "via_invoke" => fe["via_invoke"] }
          end
        end
        surface["effects"] = own_effects + via_effects
      end

      surface
    end

    def io_capability_escape_boundaries(contract)
      decls     = contract.fetch("declarations", [])
      cap_decls = decls.select { |d| d.fetch("kind") == "capability" }
      eff_decls = decls.select { |d| d.fetch("kind") == "effect_binding" }

      cap_decls.map do |cap|
        cap_name = cap.fetch("name")
        eff      = eff_decls.find { |e| e.fetch("deps", []).include?(cap_name) }
        {
          "kind"            => "io_capability",
          "name"            => eff&.fetch("name") || cap_name,
          "required_caps"   => ["IO.Capability"],
          "capability_name" => cap_name,
          "capability_type" => cap.fetch("type", {}).fetch("name", "IO.Capability")
        }
      end
    end

    def temporal_input_node(decl)
      {
        "kind" => "temporal_input_node",
        "name" => decl.fetch("name"),
        "type" => temporal_type(decl.fetch("type")),
        "store_ref" => decl.fetch("from", nil),
        "lifecycle" => decl.fetch("lifecycle", "durable"),
        "axis" => decl.fetch("temporal_axis"),
        "node_fragment_class" => decl.fetch("node_fragment_class"),
        "value_fragment_class" => decl.fetch("value_fragment_class"),
        "required_capability" => decl.fetch("required_capability"),
        "required_caps" => [decl.fetch("required_capability")],
        "fragment" => decl.fetch("fragment_class", "temporal")
      }
    end

    def temporal_access_node(decl)
      expr = decl.fetch("expr", {})
      return nil unless expr.fetch("kind", nil) == "call"

      case expr.fetch("fn")
      when "history_at"
        history_temporal_access_node(decl, expr)
      when "bihistory_at"
        bihistory_temporal_access_node(decl, expr)
      end
    end

    def history_temporal_access_node(decl, expr)
      args = expr.fetch("args", [])
      source_ref = ref_name(args[0])
      as_of_ref = ref_name(args[1])
      {
        "kind" => "temporal_access_node",
        "name" => decl.fetch("name"),
        "source_ref" => source_ref,
        "access" => "point",
        "temporal_axis" => "valid_time",
        "axis" => "valid_time",
        "as_of_ref" => as_of_ref,
        "coordinate_refs" => { "as_of" => as_of_ref },
        "result_type" => decl.fetch("type"),
        "node_fragment_class" => "temporal",
        "value_fragment_class" => "core",
        "required_capability" => "history_read",
        "required_caps" => ["history_read"],
        "evidence_policy" => "link_selected_append_observation",
        "fragment" => "temporal"
      }
    end

    def bihistory_temporal_access_node(decl, expr)
      args = expr.fetch("args", [])
      source_ref = ref_name(args[0])
      vt_ref = ref_name(args[1])
      tt_ref = ref_name(args[2])
      {
        "kind" => "temporal_access_node",
        "name" => decl.fetch("name"),
        "source_ref" => source_ref,
        "access" => "point",
        "temporal_axis" => "bitemporal",
        "axis" => "bitemporal",
        "valid_time_ref" => vt_ref,
        "transaction_time_ref" => tt_ref,
        "coordinate_refs" => {
          "valid_time" => vt_ref,
          "transaction_time" => tt_ref
        },
        "result_type" => decl.fetch("type"),
        "node_fragment_class" => "temporal",
        "value_fragment_class" => "core",
        "required_capability" => "bihistory_read",
        "required_caps" => ["bihistory_read"],
        "evidence_policy" => "link_selected_event_observation",
        "fragment" => "temporal"
      }
    end

    def temporal_type(type)
      return type unless type.is_a?(Hash)

      constructor = type.fetch("name", type.fetch("constructor", nil))
      params = type.fetch("params", [])
      element = params.first
      {
        "constructor" => constructor,
        "element_type" => element ? type_display(element) : "Unknown"
      }
    end

    def invariant_node(decl)
      result = {
        "kind" => "invariant_node",
        "name" => decl.fetch("name"),
        "predicate" => decl.fetch("predicate_ref", nil),
        "predicate_ref" => decl.fetch("predicate_ref", nil),
        "predicate_type" => decl.fetch("predicate_type", nil),
        "severity" => decl.fetch("severity", "error"),
        "label" => decl.fetch("label", nil),
        "message" => decl.fetch("message", nil),
        "overridable_with" => decl.fetch("overridable_with", nil),
        "output_effect" => decl.fetch("output_effect", invariant_output_effect(decl.fetch("severity", "error"))),
        "deps" => decl.fetch("deps", []),
        "fragment" => decl.fetch("fragment_class", "core")
      }
      result["source_span"] = decl.fetch("source_span") if decl.key?("source_span")
      result["source_metadata"] = decl.fetch("source_metadata") if decl.key?("source_metadata")
      result["threshold"] = decl.fetch("threshold") if decl.key?("threshold")
      result["threshold_ms"] = decl.fetch("threshold_ms") if decl.key?("threshold_ms")
      result
    end

    def invariant_output_effect(severity)
      case severity
      when "error" then "blocks"
      when "warn" then "warns"
      when "soft" then "uncertain"
      when "metric" then "metric"
      else "blocks"
      end
    end

    def loop_node(decl, loop_class, termination)
      # PROP-039 gate 5: lower for_loop / budgeted_loop to canonical loop_node IR shape.
      # termination field encodes the termination evidence kind:
      #   collection_exhaustion — FiniteLoop: terminates by exhausting a finite Collection[T]
      #   budget_exhaustion     — BudgetedLocalLoop: terminates by exhausting static max_steps
      # PROP-039 gate 8: body now carries typed lead_node + compute_node (was always []).
      raw_body = decl.fetch("body", [])
      body_nodes = raw_body.filter_map { |b| lower_body_node(b) }
      node = {
        "kind"        => "loop_node",
        "loop_class"  => loop_class,
        "name"        => decl.fetch("name"),
        "item"        => decl.fetch("item"),
        "source_ref"  => decl.fetch("source"),
        "termination" => termination,
        "body"        => body_nodes,
        "fragment"    => decl.fetch("fragment_class", "core")
      }
      node["max_steps"]  = decl.fetch("max_steps")  if decl.key?("max_steps")
      node["item_type"]  = decl.fetch("item_type")  if decl.key?("item_type")
      node
    end

    # PROP-039 gate 8: lower a typed body declaration to a SemanticIR body node.
    def lower_body_node(b)
      case b.fetch("kind", "")
      when "lead"
        type_ann  = b.fetch("type_annotation", "Unknown")
        type_str  = type_ann.is_a?(Hash) ? (type_ann["name"] || "Unknown") : type_ann.to_s
        {
          "kind"    => "lead_node",
          "name"    => b.fetch("name"),
          "type"    => type_str,
          "initial" => semantic_expr(b.fetch("initial", nil))
        }
      when "compute"
        {
          "kind" => "compute_node",
          "name" => b.fetch("name"),
          "expr" => semantic_expr(b.fetch("expr", nil))
        }
      end
    end

    def stream_input_node(decl, declarations)
      {
        "kind" => "stream_input_node",
        "name" => decl.fetch("name"),
        "type" => type_display(decl.fetch("type")),
        # LAB-IGNITER-STREAM-ARTIFACT-EXECUTABILITY-P2 (D law): the window binding
        # is explicit — the single declared window's ref, never a first-match guess.
        "window_ref" => decl.fetch("window_ref") { resolved_window_ref(declarations) },
        "escape_capability" => "stream_input",
        # K law (PROP-023 §3.1): the stream declaration classifies ESCAPE at the
        # emitted node — both emitters converge on this value.
        "fragment" => "escape"
      }
    end

    def window_decl_node(decl)
      result = {
        "kind" => "window_decl_node",
        "ref" => window_ref(decl),
        "key" => decl.fetch("key", decl.fetch("name")),
        "window_kind" => atom_value(decl.fetch("window_kind", decl.dig("options", "kind"))),
        "on_close" => atom_value(decl.fetch("on_close", decl.dig("options", "on_close")))
      }
      result["size"] = decl.fetch("size", decl.dig("options", "size")) if decl.key?("size") || decl.dig("options", "size")
      result["period"] = decl.fetch("period", decl.dig("options", "period")) if decl.key?("period") || decl.dig("options", "period")
      result["idle"] = decl.fetch("idle", decl.dig("options", "idle")) if decl.key?("idle") || decl.dig("options", "idle")
      result["bounded"] = window_bounded?(result)
      result.compact
    end

    def fold_stream_node(decl, declarations)
      expr = decl.fetch("expr", {})
      args = expr.fetch("args", [])
      {
        "kind" => "fold_stream_node",
        "name" => decl.fetch("name"),
        # LAB-IGNITER-STREAM-ARTIFACT-EXECUTABILITY-P2 (K law, canon ch4:96):
        # bounded fold_stream is a STREAM node whose VALUE is CORE — both
        # emitters converge on these values.
        "fragment" => "stream",
        "stream_ref" => decl.fetch("stream_ref", ref_name(args[0])),
        # C law step 2: the init is emitted through the same compute-expr path
        # as ordinary compute nodes (the typed init when the TypeChecker
        # supplied one). No literal-only lowering, no silent defaults.
        "init" => semantic_expr(decl.fetch("init", args[1])),
        "fn_ref" => decl.fetch("fn_ref") { lambda_ref(args[2]) },
        "bound" => fold_stream_bound(decl, declarations),
        "event_binding" => stream_event_binding(args[2]),
        "result_type" => decl.fetch("type"),
        "escape_capability" => "stream_input",
        "result_fragment" => "core"
      }
    end

    # LAB-IGNITER-STREAM-ARTIFACT-EXECUTABILITY-P2 (D law): explicit stream↔window
    # binding. The classifier refuses zero windows (OOF-S2 absent) and >1 windows
    # (OOF-S2 ambiguous) for any contract that folds a stream, so exactly one
    # window can reach emission — resolve it explicitly and REFUSE (never guess)
    # anything else.
    def resolved_window_ref(declarations)
      windows = declarations.select { |decl| decl.fetch("kind") == "window" }
      unless windows.length == 1
        raise "stream window binding unresolvable: #{windows.length} windows reached emission " \
              "(classifier OOF-S2 must refuse this program)"
      end
      window_ref(windows.first)
    end

    def window_ref(decl)
      decl.fetch("window_ref", decl.fetch("ref", decl.fetch("name")))
    end

    def fold_stream_bound(decl, declarations)
      # B law: the parsed bound reaches the artifact verbatim (OOF-S1/OOF-S5
      # guarantee presence and a valid n); the resolved window ref is attached
      # explicitly — never guessed (D law).
      bound = decl.fetch("bound").dup
      bound["window_ref"] ||= decl.fetch("window_ref") { resolved_window_ref(declarations) }
      bound
    end

    def window_bounded?(window)
      %w[size period idle].any? { |key| window.fetch(key, nil) }
    end

    # LAB-IGNITER-STREAM-ARTIFACT-EXECUTABILITY-P2 (B law): event_binding names
    # the accumulator lambda's VALUE parameter explicitly; the fabricated
    # value_path ["value"] demo relic is REMOVED (consumed by nothing). The
    # fold lambda names no event parameter, so event_ref keeps the "event"
    # fallback.
    def stream_event_binding(lambda_expr)
      params = lambda_expr.is_a?(Hash) ? lambda_expr.fetch("params", []) : []
      {
        "event_ref" => "event",
        "value_ref" => params[1]
      }.compact
    end

    def ref_name(expr)
      return nil unless expr.is_a?(Hash)
      return expr.fetch("name") if expr.fetch("kind", nil) == "ref"

      nil
    end

    # LAB-IGNITER-STREAM-ARTIFACT-EXECUTABILITY-P2 (A law): every fold_stream
    # accumulator gets a REAL content-addressed fn_ref plus a callable registry
    # entry (the integer_sum_lambda magic name is RETIRED). The address is
    # computed over the full callable value in the shared expr grammar:
    #   fn_ref = "lambda/" + hex(SHA256(canonical_json(callable_value)))[0,16]
    # with callable_value = {"kind"=>"callable_v1","params"=>…,"body"=>…}.
    # No captures field — closure conversion stays a VM concern.
    def lambda_ref(expr)
      return nil unless expr.is_a?(Hash) && expr.fetch("kind", nil) == "lambda"

      callable = {
        "kind" => "callable_v1",
        "params" => expr.fetch("params", []),
        "body" => expr.fetch("body", nil)
      }
      fn_ref = "lambda/#{Digest::SHA256.hexdigest(canonical_json(callable))[0, 16]}"
      (@callables ||= {})[fn_ref] = callable
      fn_ref
    end

    def atom_value(value)
      case value
      when Hash
        if value.fetch("kind", nil) == "symbol"
          value.fetch("value")
        elsif value.fetch("kind", nil) == "literal"
          value.fetch("value")
        else
          value
        end
      when Symbol
        value.to_s
      else
        value
      end
    end

    def type_display(type)
      return type unless type.is_a?(Hash)

      params = type.fetch("params", [])
      return type.fetch("name") if params.empty?

      "#{type.fetch("name")}[#{params.map { |param| type_display(param) }.join(", ")}]"
    end

    def type_shapes(parsed_program)
      parsed_program.fetch("types").each_with_object({}) do |type, shapes|
        fields = type.fetch("fields", []).each_with_object({}) do |field, index|
          index[field.fetch("name")] = normalize_type(field.fetch("type_annotation"))
        end
        shapes[type.fetch("name")] = fields
      end
    end

    def emit_contract(_parsed_program, contract, sample_input)
      diagnostics = []
      type_env = {}
      value_env = sample_input.dup
      inputs = []
      outputs = []
      nodes = [option_carrier_guard_node]

      contract.fetch("body").each do |node|
        case node.fetch("kind")
        when "input"
          type = normalize_type(node.fetch("type_annotation"))
          type_env[node.fetch("name")] = type
          inputs << { "name" => node.fetch("name"), "type" => type_ir(type), "lifecycle" => "local" }
        when "compute"
          diagnostic_count_before = diagnostics.length
          lowered = lower_expr(node.fetch("expr"), type_env, diagnostics, node.fetch("name"))
          type_env[node.fetch("name")] = lowered.fetch("type")
          value_env[node.fetch("name")] = eval_expr(node.fetch("expr"), value_env)
          fragment = diagnostics.length == diagnostic_count_before ? "core" : "oof"
          nodes << {
            "kind" => "compute",
            "name" => node.fetch("name"),
            "expr" => lowered.fetch("expr"),
            "type" => type_ir(lowered.fetch("type")),
            "deps" => lowered.fetch("deps").uniq,
            "fragment" => fragment
          }
        when "output"
          name = node.fetch("name")
          expected = normalize_type(node.fetch("type_annotation"))
          actual = type_env[name]
          if actual.nil?
            diagnostics << oof("OOF-P1", "Unresolved output source: #{name}", name)
          elsif actual != expected
            diagnostics << type_mismatch_oof(expected, actual, name)
          end
          outputs << {
            "name" => name,
            "type" => type_ir(expected),
            "lifecycle" => node.fetch("lifecycle", "session")
          }
        end
      end

      diagnostics.concat(evidence_gate_oofs(contract, sample_input, value_env))
      modifier = contract.fetch("modifier", "pure")
      fragment_class = if !diagnostics.empty?
                         "oof"
                       elsif modifier != "pure"
                         "escape"
                       else
                         "core"
                       end
      contract_ir = {
        "kind" => "contract_ir",
        "option_carrier" => "first_class_v1",
        "contract_ref" => nil,
        "contract_name" => contract.fetch("name"),
        "modifier" => modifier,
        "specialization_of" => nil,
        "type_args" => {},
        "fragment_class" => fragment_class,
        "inputs" => inputs,
        "outputs" => outputs,
        "nodes" => nodes,
        "escape_boundaries" => [],
        "diagnostics" => diagnostics
      }
      contract_ir["contract_ref"] = contract_ref(contract_ir)
      contract_ir
    end

    def contract_ref(contract_ir)
      body = contract_ir.reject { |key, _value| key == "contract_ref" || key == "diagnostics" }
      "contract/#{contract_ir.fetch("contract_name")}/sha256:#{Digest::SHA256.hexdigest(canonical_json(body))[0, 24]}"
    end

    def lower_expr(expr, type_env, diagnostics, node_name)
      case expr.fetch("kind")
      when "literal"
        type = normalize_type(expr.fetch("type_tag"))
        { "expr" => {
            "kind" => "literal",
            "value" => expr.fetch("value"),
            "type" => literal_type(type),
            "resolved_type" => type_ir(type)
          },
          "type" => type,
          "deps" => [] }
      when "ref"
        name = expr.fetch("name")
        type = type_env[name]
        unless type
          diagnostics << oof("OOF-P1", "Unresolved symbol: #{name}", node_name)
          type = "Unknown"
        end
        { "expr" => { "kind" => "ref", "name" => name, "resolved_type" => type_ir(type) },
          "type" => type,
          "deps" => [name] }
      when "field_access"
        object = lower_expr(expr.fetch("object"), type_env, diagnostics, node_name)
        field = expr.fetch("field")
        field_type = @types.fetch(object.fetch("type"), {})[field]
        unless field_type
          diagnostics << oof("OOF-P1", "Unresolved field: #{object.fetch("type")}.#{field}", node_name)
          field_type = "Unknown"
        end
        { "expr" => {
            "kind" => "field_access",
            "object" => object.fetch("expr"),
            "field" => field,
            "resolved_type" => type_ir(field_type)
          },
          "type" => field_type,
          "deps" => object.fetch("deps") }
      when "binary_op"
        lower_binary(expr, type_env, diagnostics, node_name)
      when "unary_op"
        lower_unary(expr, type_env, diagnostics, node_name)
      when "call"
        fn = expr.fetch("fn")
        diagnostics << oof("OOF-P1", "Unresolved function: #{fn}", node_name)
        { "expr" => { "kind" => "call", "fn" => fn, "args" => [], "resolved_type" => type_ir("Unknown") },
          "type" => "Unknown",
          "deps" => [] }
      else
        diagnostics << oof("OOF-P0", "Unsupported expression kind: #{expr.fetch("kind")}", node_name)
        { "expr" => {
            "kind" => "unsupported",
            "source_kind" => expr.fetch("kind"),
            "resolved_type" => type_ir("Unknown")
          },
          "type" => "Unknown",
          "deps" => [] }
      end
    end

    def lower_binary(expr, type_env, diagnostics, node_name)
      left = lower_expr(expr.fetch("left"), type_env, diagnostics, node_name)
      right = lower_expr(expr.fetch("right"), type_env, diagnostics, node_name)
      operator, result_type = operator_for(expr.fetch("op"), left.fetch("type"), right.fetch("type"), diagnostics, node_name)

      {
        "expr" => {
          "kind" => "call",
          "fn" => operator,
          "args" => [left.fetch("expr"), right.fetch("expr")],
          "resolved_type" => type_ir(result_type)
        },
        "type" => result_type,
        "deps" => left.fetch("deps") + right.fetch("deps")
      }
    end

    def lower_unary(expr, type_env, diagnostics, node_name)
      operand  = lower_expr(expr.fetch("operand"), type_env, diagnostics, node_name)
      op       = expr.fetch("op")
      fn_name, result_type = unary_operator_for(op, operand.fetch("type"), diagnostics, node_name)
      { "expr" => {
          "kind"          => "call",
          "fn"            => fn_name,
          "args"          => [operand.fetch("expr")],
          "resolved_type" => type_ir(result_type)
        },
        "type" => result_type,
        "deps" => operand.fetch("deps") }
    end

    def unary_operator_for(op, operand_type, diagnostics, node_name)
      case op
      when "!"
        unless operand_type == "Unknown" || operand_type == "Bool"
          diagnostics << oof("OOF-TY0",
            "stdlib.primitive.not: expected Bool operand, got #{operand_type}", node_name)
        end
        ["stdlib.primitive.not", "Bool"]
      when "-"
        unless operand_type == "Unknown" || operand_type == "Integer"
          diagnostics << oof("OOF-TY0",
            "stdlib.integer.neg: expected Integer operand, got #{operand_type}", node_name)
        end
        ["stdlib.integer.neg", "Integer"]
      else
        diagnostics << oof("OOF-P0", "Unsupported unary operator: #{op}", node_name)
        ["stdlib.unsupported.#{op}", "Unknown"]
      end
    end

    def operator_for(op, left_type, right_type, diagnostics, node_name)
      case op
      when "+"
        unless unknown_type?(left_type, right_type) || (left_type == "Integer" && right_type == "Integer")
          diagnostics << oof("OOF-TY0", "Integer add requires Integer operands", node_name)
        end
        ["stdlib.integer.add", "Integer"]
      when "-"
        unless unknown_type?(left_type, right_type) || (left_type == "Integer" && right_type == "Integer")
          diagnostics << oof("OOF-TY0", "Integer sub requires Integer operands", node_name)
        end
        ["stdlib.integer.sub", "Integer"]
      when "*"
        unless unknown_type?(left_type, right_type) || (left_type == "Integer" && right_type == "Integer")
          diagnostics << oof("OOF-TY0", "Integer mul requires Integer operands", node_name)
        end
        ["stdlib.integer.mul", "Integer"]
      when "/"
        unless unknown_type?(left_type, right_type) || (left_type == "Integer" && right_type == "Integer")
          diagnostics << oof("OOF-TY0", "Integer div requires Integer operands", node_name)
        end
        ["stdlib.integer.div", "Integer"]
      when ">"
        unless unknown_type?(left_type, right_type) || (left_type == "Integer" && right_type == "Integer")
          diagnostics << oof("OOF-TY0", "Integer comparison requires Integer operands", node_name)
        end
        ["stdlib.integer.gt", "Bool"]
      when "<"
        unless unknown_type?(left_type, right_type) || (left_type == "Integer" && right_type == "Integer")
          diagnostics << oof("OOF-TY0", "Integer comparison requires Integer operands", node_name)
        end
        ["stdlib.integer.lt", "Bool"]
      when "<="
        unless unknown_type?(left_type, right_type) || (left_type == "Integer" && right_type == "Integer")
          diagnostics << oof("OOF-TY0", "Integer comparison requires Integer operands", node_name)
        end
        ["stdlib.integer.lte", "Bool"]
      when ">="
        unless unknown_type?(left_type, right_type) || (left_type == "Integer" && right_type == "Integer")
          diagnostics << oof("OOF-TY0", "Integer comparison requires Integer operands", node_name)
        end
        ["stdlib.integer.gte", "Bool"]
      when "&&"
        unless unknown_type?(left_type, right_type) || (left_type == "Bool" && right_type == "Bool")
          diagnostics << oof("OOF-TY0", "Boolean and requires Bool operands", node_name)
        end
        ["stdlib.bool.and", "Bool"]
      when "||"
        unless unknown_type?(left_type, right_type) || (left_type == "Bool" && right_type == "Bool")
          diagnostics << oof("OOF-TY0", "Boolean or requires Bool operands", node_name)
        end
        ["stdlib.bool.or", "Bool"]
      when "==", "!="
        unless equality_type_names_compatible?(left_type, right_type)
          diagnostics << oof("OOF-TY0", "Type mismatch for #{op}: cannot compare #{left_type} with #{right_type}", node_name)
        end
        [op == "==" ? "stdlib.primitive.eq" : "stdlib.primitive.ne", "Bool"]
      else
        diagnostics << oof("OOF-P0", "Unsupported operator: #{op}", node_name)
        ["stdlib.unsupported.#{op}", "Unknown"]
      end
    end

    def unknown_type?(*types)
      types.any? { |type| type == "Unknown" }
    end

    def equality_type_names_compatible?(left, right)
      unknown_type?(left, right) ||
        %w[String Text].include?(left) && %w[String Text].include?(right) ||
        left == right && %w[Integer Bool Float Decimal].include?(left)
    end

    def eval_expr(expr, env)
      case expr.fetch("kind")
      when "literal"
        expr.fetch("value")
      when "ref"
        env[expr.fetch("name")]
      when "field_access"
        object = eval_expr(expr.fetch("object"), env)
        object&.fetch(expr.fetch("field"), nil)
      when "binary_op"
        left = eval_expr(expr.fetch("left"), env)
        right = eval_expr(expr.fetch("right"), env)
        return nil if left.nil? || right.nil?

        case expr.fetch("op")
        when "+" then left + right
        when ">" then left > right
        when "==" then left == right
        when "!=" then left != right
        when "&&" then left && right
        when "||" then left || right
        else nil
        end
      else
        nil
      end
    end

    def evidence_gate_oofs(contract, sample_input, value_env)
      return [] unless contract.fetch("name").include?("EvidenceLinkedAlert") ||
                       contract.fetch("name").include?("EvidenceLessAlert")

      alert = sample_input.fetch("alert", {})
      diagnostics = []
      if alert.fetch("signal_count", 0) < 1 || alert.fetch("claim_count", 0) < 1
        diagnostics << oof(
          "OOF-OS2",
          "EvidenceLinkedAlert requires non-empty signal_refs and claim_refs",
          contract.fetch("name")
        )
      end
      if alert.fetch("valid_until", "").to_s.empty?
        diagnostics << oof("OOF-OS4", "EvidenceLinkedAlert requires valid_until", contract.fetch("name"))
      end
      if value_env.key?("allowed") && value_env.fetch("allowed") != true && diagnostics.empty?
        diagnostics << oof("OOF-OS2", "EvidenceLinkedAlert gate did not pass", contract.fetch("name"))
      end
      diagnostics
    end

    def type_mismatch_oof(expected, actual, node_name)
      if expected == "Bool" && actual == "ConfidenceLabel"
        oof("OOF-CE4", "ConfidenceLabel cannot be used as Bool", node_name)
      else
        oof("OOF-TY0", "Type mismatch: expected #{expected}, got #{actual}", node_name)
      end
    end

    def normalize_type(type)
      type.is_a?(Hash) ? type.fetch("name") : type.to_s
    end

    def type_ir(type)
      { "name" => type, "params" => [] }
    end

    def literal_type(type)
      {
        "Integer" => "int",
        "Float" => "float",
        "String" => "string",
        "Bool" => "bool",
        "Nil" => "nil"
      }.fetch(type, type.downcase)
    end

    def dedupe_oofs(entries)
      entries.uniq { |entry| [entry.fetch("rule"), entry.fetch("message"), entry.fetch("node"), entry.fetch("line")] }
    end

    def canonical_json(value)
      JSON.generate(deep_sort(value))
    end

    def deep_sort(value)
      case value
      when Hash
        value.keys.sort.each_with_object({}) { |key, sorted| sorted[key] = deep_sort(value[key]) }
      when Array
        value.map { |item| deep_sort(item) }
      else
        value
      end
    end

    def oof(rule, message, node_name)
      { "rule" => rule, "message" => message, "node" => node_name, "line" => nil }
    end

    def diagnostic(entry)
      normalized = {
        "rule" => entry.fetch("rule"),
        "severity" => "error",
        "message" => entry.fetch("message"),
        "node" => entry.fetch("node"),
        "path" => nil,
        "line" => entry.fetch("line")
      }
      # LANG-APP-LOCAL-DEF-CALL-CANON-ADOPTION-P2 (PROP-051 §4): def-law
      # diagnostics carry a full source span; pass `col` through so the report
      # enrichment (Diagnostics.span_for) can preserve it end-to-end.
      normalized["col"] = entry.fetch("col") if entry.key?("col")
      normalized
    end
  end
end
