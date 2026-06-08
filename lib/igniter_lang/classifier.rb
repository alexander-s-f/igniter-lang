# frozen_string_literal: true

require "digest"

module IgniterLang
  class Classifier
    DEFAULT_VERSION = "classifier-pass-executable-proof-v0"

    def initialize(classifier_version: DEFAULT_VERSION)
      @classifier_version = classifier_version
    end

    def classify(parsed_program, sample_input:)
      assumption_registry = assumption_registry(parsed_program)
      # PROP-040: build profile index for OOF-M7/M8 validation
      profile_index = parsed_program.fetch("profiles", [])
                                    .each_with_object({}) { |p, h| h[p.fetch("name")] = p }
      contracts = parsed_program.fetch("contracts").map do |contract|
        classify_contract(parsed_program, contract, sample_input, assumption_registry, profile_index)
      end

      result = {
        "kind" => "classified_program",
        "classifier_version" => @classifier_version,
        "program_id" => program_id(parsed_program),
        "source_path" => parsed_program.fetch("source_path"),
        "source_hash" => parsed_program.fetch("source_hash"),
        "grammar_version" => parsed_program.fetch("grammar_version"),
        "module" => parsed_program.fetch("module"),
        "type_declarations" => type_declarations(parsed_program),
        "contracts" => contracts,
        "oof_log" => contracts.flat_map { |contract| contract.fetch("oof_log") },
        "semantic_ir_ref" => nil
      }
      result["assumption_registry"] = assumption_registry.values unless assumption_registry.empty?
      olap_points = parsed_program.fetch("olap_points", [])
      result["olap_points"] = olap_points unless olap_points.empty?
      result
    end

    def type_declarations(parsed_program)
      parsed_program.fetch("types", []).map do |type|
        {
          "kind" => "type",
          "name" => type.fetch("name"),
          "fields" => type.fetch("fields", []).map do |field|
            {
              "name" => field.fetch("name"),
              "type_annotation" => normalize_type(field.fetch("type_annotation")),
              "optional" => field.fetch("optional", false)
            }
          end
        }
      end
    end

    private

    def program_id(parsed_program)
      seed = [
        parsed_program.fetch("source_path"),
        parsed_program.fetch("grammar_version"),
        parsed_program.fetch("source_hash"),
        @classifier_version
      ].join("|")
      "classifier_pass/#{Digest::SHA256.hexdigest(seed)[0, 16]}"
    end

    def classify_contract(parsed_program, contract, sample_input, assumption_registry, profile_index = {})
      diagnostics = []
      declarations = []
      assumption_refs = []
      symbol_fragments = {}
      symbol_kinds = {}
      compute_exprs = {}
      window_declarations = []
      fold_stream_stream_refs = Hash.new { |refs, stream_name| refs[stream_name] = [] }
      capability_declarations = {}  # PROP-035: cap_name => node
      effect_bindings = []          # PROP-035: cap_refs that have effect bindings
      evidence_output_names = []    # PROP-034: output names that carry evidence refs
      parsed_program.fetch("olap_points", []).each do |point|
        symbol_fragments[point.fetch("name")] = "escape"
        symbol_kinds[point.fetch("name")] = "olap_point"
      end

      contract.fetch("body").each do |node|
        case node.fetch("kind")
        when "input"
          symbol_fragments[node.fetch("name")] = "core"
          symbol_kinds[node.fetch("name")] = "input"
          declarations << classified_decl(node, "core", [], [])
        when "escape"
          declarations << classified_decl(node, "escape", [], [])
        when "stream"
          symbol_fragments[node.fetch("name")] = "escape"
          symbol_kinds[node.fetch("name")] = "stream"
          declarations << classified_decl(node, "escape", [], [])
        when "capability"
          # PROP-035: capability <name>: <CapType>
          symbol_fragments[node.fetch("name")] = "escape"
          symbol_kinds[node.fetch("name")] = "capability"
          capability_declarations[node.fetch("name")] = node
          declarations << classified_decl(node, "escape", [], [])
        when "effect_binding"
          # PROP-035: effect <name> using <cap_ref>
          cap_ref = node.fetch("capability_ref")
          effect_bindings << cap_ref
          unless capability_declarations.key?(cap_ref)
            diagnostics << oof(
              "OOF-M4",
              "effect binding '#{node.fetch("name")}' references undeclared capability '#{cap_ref}'",
              node.fetch("name")
            )
          end
          symbol_fragments[node.fetch("name")] = "escape"
          symbol_kinds[node.fetch("name")] = "effect_binding"
          deps = capability_declarations.key?(cap_ref) ? [cap_ref] : []
          declarations << classified_decl(node, "escape", deps, [])
        when "read"
          fragment = temporal_type?(node["type_annotation"]) ? "temporal" : "escape"
          symbol_fragments[node.fetch("name")] = fragment == "temporal" ? "core" : "escape"
          symbol_kinds[node.fetch("name")] = fragment == "temporal" ? "temporal_read" : "read"
          declarations << classified_decl(node, fragment, [], []).merge(value_fragment_metadata(fragment, node["type_annotation"]))
        when "window"
          window_declarations << node
          declarations << classified_decl(node.merge("name" => node.fetch("label", "_window")), "escape", [], [])
        when "uses_assumptions"
          name = node.fetch("name")
          assumption_refs << name
          symbol_fragments[name] = "core"
          symbol_kinds[name] = "assumption"
          missing = assumption_registry.key?(name) ? [] : [name]
          unless missing.empty?
            diagnostics << oof(
              "OOF-A1",
              "contract '#{contract.fetch("name")}' uses assumptions '#{name}' but no " \
              "assumption named '#{name}' is declared in this module",
              "uses_assumptions:#{name}"
            )
          end
          declarations << classified_decl(node, "epistemic", [], missing)
        when "fold_stream"
          bound = node.fetch("bound", nil)
          result_fragment = bound ? "core" : "oof"
          deps = expr_refs(node.fetch("expr", { "kind" => "literal", "value" => nil }))
          deps.select { |dep| symbol_kinds[dep] == "stream" }.each do |stream_name|
            fold_stream_stream_refs[stream_name] << node.fetch("name")
          end
          symbol_fragments[node.fetch("name")] = result_fragment
          symbol_kinds[node.fetch("name")] = "fold_stream"
          declarations << classified_decl(node, result_fragment, deps, [])
        when "invariant"
          deps = [node.fetch("predicate_ref", nil)].compact
          missing = deps.reject { |dep| symbol_fragments.key?(dep) }
          missing.each do |name|
            diagnostics << oof("OOF-P1", "Unresolved symbol: #{name}", node.fetch("name"))
          end
          declarations << classified_decl(node, missing.empty? ? "core" : "oof", deps, missing)
            .merge(invariant_author_fields(node))
            .merge("source_metadata" => invariant_source_metadata(parsed_program, node))
        when "compute"
          deps = expr_refs(node.fetch("expr"))
          missing = deps.reject { |dep| symbol_fragments.key?(dep) }
          missing.each do |name|
            diagnostics << oof("OOF-P1", "Unresolved symbol: #{name}", node.fetch("name"))
          end
          stream_deps = deps.select { |dep| symbol_kinds[dep] == "stream" }
          stream_deps.each do |stream_name|
            diagnostics << oof("OOF-S4", "Direct use of stream '#{stream_name}' is OOF - use fold_stream instead", node.fetch("name"))
          end
          upstream_oof = deps.any? { |dep| symbol_fragments[dep] == "oof" }
          fragment = missing.empty? && stream_deps.empty? && !upstream_oof ? "core" : "oof"
          symbol_fragments[node.fetch("name")] = fragment
          symbol_kinds[node.fetch("name")] = "compute"
          compute_exprs[node.fetch("name")] = node.fetch("expr")
          declarations << classified_decl(node, fragment, deps, missing)
        when "output"
          name = node.fetch("name")
          missing = symbol_fragments.key?(name) ? [] : [name]
          diagnostics << oof("OOF-P1", "Unresolved output source: #{name}", name) unless missing.empty?
          src_fragment = symbol_fragments.fetch(name, "oof")
          fragment = missing.empty? && src_fragment == "core" ? "core" : "oof"
          confidence_oof = confidence_as_bool_oof(node, compute_exprs[name])
          diagnostics << confidence_oof if confidence_oof
          fragment = "oof" if confidence_oof
          # PROP-034: track outputs with evidence refs for post-loop OOF-M9 check
          evidence_output_names << name if node.key?("evidence") && !node.fetch("evidence").empty?
          declarations << classified_decl(node, fragment, [name], missing)
        when "lead"
          # PROP-039 gate 8: lead at contract level — pass through so TypeChecker can emit OOF-L5
          declarations << classified_decl(node, "oof", [], [])
        when "for_loop"
          # PROP-039 gate 4: FiniteLoop — classify loop node with source dep
          source = node.fetch("source")
          source_missing = symbol_fragments.key?(source) ? [] : [source]
          source_missing.each do |s|
            diagnostics << oof("OOF-P1", "for loop source '#{s}' is not declared", node.fetch("name"))
          end
          src_frag = source_missing.empty? ? symbol_fragments.fetch(source, "core") : "oof"
          decl = classified_decl(node, source_missing.empty? ? src_frag : "oof", [source], source_missing)
          decl["source"] = source
          decl["item"]   = node.fetch("item")
          # PROP-039 gate 8: pass loop body through for TypeChecker body scope validation
          decl["body"]   = node.fetch("body", [])
          declarations << decl
        when "budgeted_loop"
          # PROP-039 gate 4: BudgetedLocalLoop — classify loop node with source dep
          source = node.fetch("source")
          source_missing = symbol_fragments.key?(source) ? [] : [source]
          source_missing.each do |s|
            diagnostics << oof("OOF-P1", "budgeted loop source '#{s}' is not declared", node.fetch("name"))
          end
          src_frag = source_missing.empty? ? symbol_fragments.fetch(source, "core") : "oof"
          decl = classified_decl(node, source_missing.empty? ? src_frag : "oof", [source], source_missing)
          decl["source"] = source
          decl["item"]   = node.fetch("item")
          decl["max_steps"] = node.fetch("max_steps") if node.key?("max_steps")
          # PROP-039 gate 8: pass loop body through for TypeChecker body scope validation
          decl["body"]   = node.fetch("body", [])
          declarations << decl
        when "decreases", "max_steps"
          # PROP-039 gate 4: structural meta-declarations — no named symbol produced.
          # Used only for OOF-R2/R4 post-body checks below; not added to declarations.
          nil
        end
      end

      diagnostics.concat(stream_missing_window_oofs(fold_stream_stream_refs, window_declarations))
      diagnostics.concat(evidence_gate_oofs(contract, sample_input))

      modifier = contract.fetch("modifier", "pure")

      # PROP-035: OOF-M2 — pure contract with capability declaration
      if modifier == "pure" && capability_declarations.any?
        diagnostics << oof(
          "OOF-M2",
          "pure contract '#{contract.fetch("name")}' cannot declare IO capabilities; " \
          "use 'effect' modifier",
          contract.fetch("name")
        )
      end

      # PROP-035: OOF-M5 — capability declared but has no effect binding
      capability_declarations.each_key do |cap_name|
        unless effect_bindings.include?(cap_name)
          diagnostics << oof(
            "OOF-M5",
            "capability '#{cap_name}' declared but has no effect...using binding",
            cap_name
          )
        end
      end

      if modifier == "pure"
        escape_decl = declarations.find { |decl| decl.fetch("fragment_class") == "escape" }
        if escape_decl
          diagnostics << oof(
            "OOF-M1",
            "pure contract '#{contract.fetch("name")}' cannot declare escape capabilities; " \
            "use 'observed' for read-only external access",
            contract.fetch("name")
          )
        end
      end

      # PROP-034: OOF-M9 — pure contract with evidence refs on output (must precede contract_fragment_for)
      if modifier == "pure" && evidence_output_names.any?
        diagnostics << oof(
          "OOF-M9",
          "pure contract '#{contract.fetch("name")}' cannot declare output evidence refs " \
          "(#{evidence_output_names.join(", ")}); use 'observed' or higher modifier",
          contract.fetch("name")
        )
      end

      # PROP-039 gate 4: OOF-R2 — recursive contract must declare a decreases variant
      if modifier == "recursive"
        has_decreases = contract.fetch("body").any? { |n| n.fetch("kind") == "decreases" }
        unless has_decreases
          diagnostics << oof(
            "OOF-R2",
            "recursive contract '#{contract.fetch("name")}' requires a 'decreases' declaration",
            contract.fetch("name")
          )
        end
        # OOF-R4: recursive + decreases fuel requires a static max_steps
        fuel_shorthand = contract.fetch("body").any? do |n|
          n.fetch("kind") == "decreases" && n.fetch("variant", "") == "fuel"
        end
        if fuel_shorthand
          has_max_steps = contract.fetch("body").any? { |n| n.fetch("kind") == "max_steps" }
          unless has_max_steps
            diagnostics << oof(
              "OOF-R4",
              "recursive contract '#{contract.fetch("name")}' with 'decreases fuel' requires static max_steps",
              contract.fetch("name")
            )
          end
        end
      end

      # PROP-039 gate 4: OOF-R4 — fuel_bounded contract must declare a static max_steps
      if modifier == "fuel_bounded"
        has_max_steps = contract.fetch("body").any? { |n| n.fetch("kind") == "max_steps" }
        unless has_max_steps
          diagnostics << oof(
            "OOF-R4",
            "fuel_bounded contract '#{contract.fetch("name")}' requires a static max_steps declaration",
            contract.fetch("name")
          )
        end
      end

      # PROP-040: OOF-M7/M8 — profile binding validation (must precede contract_fragment_for)
      via_profile = contract.fetch("via_profile", nil)
      profile_authority = nil
      if via_profile
        if profile_index.key?(via_profile)
          resolved = profile_index.fetch(via_profile)
          profile_authority = resolved.fetch("authority", nil)
          # OOF-M7: contract modifier authority below profile declared authority
          modifier_rank = { "pure" => 0, "observed" => 1, "effect" => 2,
                            "privileged" => 3, "irreversible" => 4 }
          mod_rank  = modifier_rank.fetch(modifier, 0)
          prof_rank = modifier_rank.fetch(profile_authority.to_s, 0)
          if mod_rank < prof_rank
            diagnostics << oof(
              "OOF-M7",
              "contract '#{contract.fetch("name")}' (#{modifier}) cannot bind profile " \
              "'#{via_profile}' which requires '#{profile_authority}' or higher",
              contract.fetch("name")
            )
          end
        else
          # OOF-M8: profile name not declared in module
          diagnostics << oof(
            "OOF-M8",
            "contract '#{contract.fetch("name")}' binds unknown profile '#{via_profile}'; " \
            "declare 'profile #{via_profile}' in this module",
            contract.fetch("name")
          )
        end
      end

      contract_fragment = contract_fragment_for(declarations, diagnostics, modifier: modifier)

      result = {
        "kind" => "classified_contract",
        "contract_id" => contract_id(parsed_program, contract),
        "name" => contract.fetch("name"),
        "modifier" => modifier,
        "fragment_class" => contract_fragment,
        "symbols" => symbol_table(symbol_kinds, symbol_fragments),
        "declarations" => declarations,
        "dependency_graph" => dependency_graph(declarations),
        "oof_log" => diagnostics
      }
      # PROP-033/040: propagate via_profile and resolved profile_authority
      result["via_profile"]       = via_profile       if via_profile
      result["profile_authority"] = profile_authority  if profile_authority
      result["assumption_refs"]   = assumption_refs.uniq unless assumption_refs.empty?
      result
    end

    def contract_fragment_for(declarations, diagnostics, modifier: "pure")
      return "oof" unless diagnostics.empty?
      return "core" if declarations.all? { |decl| decl.fetch("fragment_class") == "core" }
      return "temporal" if declarations.any? { |decl| decl.fetch("fragment_class") == "temporal" } &&
                           declarations.none? { |decl| decl.fetch("fragment_class") == "oof" }
      return "escape" if (modifier != "pure" || declarations.any? { |decl| decl.fetch("fragment_class") == "escape" }) &&
                         declarations.none? { |decl| decl.fetch("fragment_class") == "oof" }
      return "epistemic" if declarations.any? { |decl| decl.fetch("fragment_class") == "epistemic" } &&
                            declarations.none? { |decl| decl.fetch("fragment_class") == "oof" }

      "oof"
    end

    def assumption_registry(parsed_program)
      parsed_program.fetch("assumptions", []).each_with_object({}) do |assumption, registry|
        name = assumption.fetch("name")
        registry[name] = {
          "kind" => "assumption_entry",
          "name" => name,
          "fields" => assumption.fetch("fields", {}),
          "declared_in_module" => parsed_program.fetch("module")
        }
      end
    end

    def stream_missing_window_oofs(fold_stream_stream_refs, window_declarations)
      return [] unless window_declarations.empty?

      fold_stream_stream_refs.keys.sort.map do |stream_name|
        oof("OOF-S2", "stream '#{stream_name}' has no window - every stream must declare a window", stream_name)
      end
    end

    def contract_id(parsed_program, contract)
      [parsed_program.fetch("module"), contract.fetch("name")].compact.join(".")
    end

    def classified_decl(node, fragment, deps, missing)
      result = {
        "decl_id" => decl_id(node),
        "kind" => node.fetch("kind"),
        "name" => node.fetch("name"),
        "fragment_class" => fragment,
        "deps" => deps,
        "missing_refs" => missing
      }
      result["type_annotation"] = normalized_type_annotation(node["type_annotation"]) if node.key?("type_annotation")
      if node.key?("expr")
        result["expr_kind"] = node.fetch("expr").fetch("kind")
        result["expr"] = node.fetch("expr")
      end
      %w[bound options evidence].each do |key|  # PROP-034: evidence passthrough
        result[key] = node.fetch(key) if node.key?(key)
      end
      result
    end

    def invariant_author_fields(node)
      %w[predicate_ref severity label message overridable_with source_span threshold threshold_ms].each_with_object({}) do |key, result|
        result[key] = node.fetch(key) if node.key?(key)
      end
    end

    def invariant_source_metadata(parsed_program, node)
      {
        "kind" => "invariant",
        "source_path" => parsed_program.fetch("source_path", nil),
        "source_span" => node.fetch("source_span", nil),
        "name" => node.fetch("name"),
        "severity" => node.fetch("severity", "error"),
        "label" => node.fetch("label", nil),
        "message" => node.fetch("message", nil)
      }
    end

    def value_fragment_metadata(fragment, type)
      return {} unless fragment == "temporal"

      type_name = normalize_type(type)
      {
        "node_fragment_class" => "temporal",
        "value_fragment_class" => "core",
        "required_capability" => temporal_capability(type_name),
        "temporal_axis" => temporal_axis(type_name)
      }
    end

    def temporal_capability(type_name)
      type_name == "BiHistory" ? "bihistory_read" : "history_read"
    end

    def temporal_axis(type_name)
      type_name == "BiHistory" ? "bitemporal" : "valid_time"
    end

    def decl_id(node)
      "#{node.fetch("kind")}:#{node.fetch("name")}"
    end

    def symbol_table(symbol_kinds, symbol_fragments)
      symbol_kinds.keys.sort.map do |name|
        {
          "name" => name,
          "kind" => symbol_kinds.fetch(name),
          "fragment_class" => symbol_fragments.fetch(name)
        }
      end
    end

    def dependency_graph(declarations)
      declaration_ids = declarations.map { |decl| decl.fetch("decl_id") }
      symbol_producers = declarations.each_with_object({}) do |decl, index|
        next unless %w[input compute].include?(decl.fetch("kind"))

        index[decl.fetch("name")] = decl.fetch("decl_id")
      end
      edges = declarations.flat_map do |decl|
        decl.fetch("deps").filter_map do |dep|
          from = symbol_producers[dep]
          next unless from

          { "from" => from, "to" => decl.fetch("decl_id"), "kind" => "symbol" }
        end
      end
      { "nodes" => declaration_ids, "edges" => edges }
    end

    def expr_refs(expr)
      return [] unless expr.is_a?(Hash)
      unless expr.key?("kind")
        return expr.values.flat_map do |value|
          case value
          when Hash then expr_refs(value)
          when Array then value.flat_map { |item| expr_refs(item) }
          else []
          end
        end.uniq
      end

      case expr.fetch("kind")
      when "ref"
        [expr.fetch("name")]
      when "field_access"
        expr_refs(expr.fetch("object"))
      when "binary_op"
        expr_refs(expr.fetch("left")) + expr_refs(expr.fetch("right"))
      when "call"
        expr.fetch("args", []).flat_map { |arg| expr_refs(arg) }
      when "lambda"
        params = expr.fetch("params", [])
        body_refs = expr_refs(expr.fetch("body"))
        body_refs - params
      when "literal", "symbol"
        []
      else
        expr.values.flat_map { |value| value.is_a?(Hash) ? expr_refs(value) : [] }
      end.uniq
    end

    def confidence_as_bool_oof(output_node, expr)
      return nil unless normalize_type(output_node.fetch("type_annotation")) == "Bool"
      return nil unless confidence_label_expr?(expr)

      oof("OOF-CE4", "ConfidenceLabel cannot be used as Bool", output_node.fetch("name"))
    end

    def confidence_label_expr?(expr)
      return false unless expr
      return true if expr.fetch("kind") == "field_access" && expr.fetch("field") == "confidence_label"

      false
    end

    def evidence_gate_oofs(contract, sample_input)
      return [] unless evidence_alert_contract?(contract)

      alert = sample_input.fetch("alert", {})
      diagnostics = []
      if alert.fetch("signal_count", 0) < 1 || alert.fetch("claim_count", 0) < 1
        diagnostics << oof(
          "OOF-OS2",
          "EvidenceLinkedAlert requires non-empty signal_refs and claim_refs",
          contract.fetch("name")
        )
      end
      diagnostics
    end

    def evidence_alert_contract?(contract)
      contract.fetch("body").any? do |node|
        node.fetch("kind") == "input" &&
          normalize_type(node.fetch("type_annotation")) == "EvidenceLinkedAlertInput"
      end
    end

    def normalize_type(type)
      type.is_a?(Hash) ? type.fetch("name") : type.to_s
    end

    def normalized_type_annotation(type)
      return type unless type.is_a?(Hash)

      type
    end

    def temporal_type?(type)
      %w[History BiHistory].include?(normalize_type(type))
    end

    def oof(rule, message, node_name)
      { "rule" => rule, "message" => message, "node" => node_name, "line" => nil }
    end
  end
end
