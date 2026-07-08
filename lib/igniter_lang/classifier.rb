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
      # PROP-041: pass size_relation declarations through to TypeChecker
      size_relations = parsed_program.fetch("size_relations", [])
      result["size_relations"] = size_relations unless size_relations.empty?
      entrypoint = parsed_program.fetch("entrypoint", nil)
      result["entrypoint"] = entrypoint if entrypoint
      # PROP-044 P5: variant declarations for TypeChecker @variant_shapes
      variant_decls = variant_declarations(parsed_program)
      result["variant_declarations"] = variant_decls unless variant_decls.empty?
      # OOF-L4: pass def functions through for typechecker recursion check
      functions = parsed_program.fetch("functions", [])
      result["functions"] = functions unless functions.empty?
      # PROP-045: propagate module-level intent_text
      module_intent = parsed_program.fetch("intent_text", nil)
      result["intent_text"] = module_intent if module_intent
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
              "type_annotation" => normalized_type_annotation(field.fetch("type_annotation")),  # PROP-043 C1: preserve Map[K,V] params
              "optional" => field.fetch("optional", false)
            }
          end
        }
      end
    end

    # PROP-044 P5: surface variant declarations for TypeChecker @variant_shapes
    def variant_declarations(parsed_program)
      parsed_program.fetch("variants", []).map do |variant|
        {
          "kind" => "variant",
          "name" => variant.fetch("name"),
          "arms" => variant.fetch("arms", []).map do |arm|
            {
              "name"   => arm.fetch("name"),
              "fields" => arm.fetch("fields", []).map do |field|
                {
                  "name"            => field.fetch("name"),
                  "type_annotation" => normalized_type_annotation(field.fetch("type_annotation"))
                }
              end
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
      contract_ref_declarations = []  # LANG-TYPED-CONTRACT-REF-PROP-P3
      symbol_fragments = {}
      symbol_kinds = {}
      compute_exprs = {}
      window_declarations = []
      fold_stream_stream_refs = Hash.new { |refs, stream_name| refs[stream_name] = [] }
      capability_declarations = {}  # PROP-035: cap_name => node
      effect_bindings = []          # PROP-035: cap_refs that have effect bindings
      effect_surface_meta = Hash.new { |h, k| h[k] = [] } # LANG-EFFECT-SURFACE-RECEIPT-FAILURE-P1: "receipt"/"failure" => nodes
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
          symbol_fragments[node.fetch("name")] = "stream"
          symbol_kinds[node.fetch("name")] = "stream"
          declarations << classified_decl(node, "stream", [], []).merge(stream_value_fragment_metadata("stream"))
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
        when "receipt", "failure"
          # LANG-EFFECT-SURFACE-RECEIPT-FAILURE-P1: Effect Surface metadata clauses.
          # Pure metadata: they declare the audit-proof / declared-failure types and
          # carry no behavior, so they classify as "core" and do not flip the
          # contract's fragment class (the effect-ness comes from the modifier and
          # capability/effect declarations). Placement rules run post-loop (OOF-M6).
          kind = node.fetch("kind")
          effect_surface_meta[kind] << node
          declarations << classified_decl(node.merge("name" => kind), "core", [], [])
        when "idempotency"
          # LANG-EFFECT-SURFACE-IDEMPOTENCY-P2: Effect Surface metadata — the
          # idempotency contract of an effectful operation. Same core-metadata
          # treatment as receipt/failure; the key expression (mode "key") flows
          # through classified_decl's standard "expr" passthrough. Placement rules
          # run post-loop (OOF-M6; observed is refused — idempotency governs the
          # retry of mutations, and an observation has no mutation to dedupe).
          effect_surface_meta["idempotency"] << node
          declarations << classified_decl(node.merge("name" => "idempotency"), "core", [], [])
                            .merge("mode" => node.fetch("mode"))
        when "affects"
          # LANG-EFFECT-SURFACE-AFFECTS-P5: Effect Surface metadata — names the
          # system the contract mutates. Same core-metadata treatment; placement
          # rules run post-loop (OOF-M6; observed refused — an observation
          # mutates nothing, so it has no affects target).
          effect_surface_meta["affects"] << node
          declarations << classified_decl(node.merge("name" => "affects"), "core", [], [])
                            .merge("scope" => node.fetch("scope"), "target" => node.fetch("target"))
        when "compensation"
          # LANG-EFFECT-SURFACE-COMPENSATION-P22: Effect Surface metadata — names
          # the compensating contract. Declaration only (no authority, no host
          # binding, no execution). Placement + mutual exclusion post-loop (OOF-M6).
          effect_surface_meta["compensation"] << node
          declarations << classified_decl(node.merge("name" => "compensation"), "core", [], [])
                            .merge("contract_ref" => node.fetch("contract_ref"))
        when "no_compensation"
          # LANG-EFFECT-SURFACE-COMPENSATION-P22: explicit waiver — distinct from
          # absence (the three-state distinction is load-bearing, Covenant P17).
          effect_surface_meta["no_compensation"] << node
          declarations << classified_decl(node.merge("name" => "no_compensation"), "core", [], [])
        when "reversibility"
          # LANG-EFFECT-SURFACE-REVERSIBILITY-P25: the last Effect Surface metadata
          # field — where the action sits on the ch12 scale. Metadata only;
          # placement/duplicate/contradiction run post-loop (OOF-M6).
          effect_surface_meta["reversibility"] << node
          declarations << classified_decl(node.merge("name" => "reversibility"), "core", [], [])
                            .merge("value" => node.fetch("value"))
        when "authority"
          # LANG-EFFECT-SURFACE-AUTHORITY-PARSER-P10: declared authority intent
          # (ratified model F). Core metadata; placement post-loop (OOF-M6;
          # observed refused — authority gates mutation execution).
          effect_surface_meta["authority"] << node
          declarations << classified_decl(node.merge("name" => "authority"), "core", [], [])
                            .merge("ref" => node.fetch("ref"))
        when "read"
          fragment = temporal_type?(node["type_annotation"]) ? "temporal" : "escape"
          symbol_fragments[node.fetch("name")] = fragment == "temporal" ? "core" : "escape"
          symbol_kinds[node.fetch("name")] = fragment == "temporal" ? "temporal_read" : "read"
          declarations << classified_decl(node, fragment, [], []).merge(value_fragment_metadata(fragment, node["type_annotation"]))
        when "window"
          window_declarations << node
          declarations << classified_decl(node.merge("name" => node.fetch("label", "_window")), "stream", [], [])
            .merge(stream_value_fragment_metadata("core"))
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
        when "uses_contract"
          # LANG-TYPED-CONTRACT-REF-PROP-P3: metadata-only typed contract reference.
          # Does not produce a local symbol; does not affect fragment classification.
          contract_ref_declarations << node
          cd = classified_decl(node, "metadata", [], [])
          cd["target"] = node.fetch("target")
          declarations << cd
        when "fold_stream"
          bound = node.fetch("bound", nil)
          node_fragment = bound ? "stream" : "oof"
          value_fragment = bound ? "core" : "oof"
          deps = expr_refs(node.fetch("expr", { "kind" => "literal", "value" => nil }))
          deps.select { |dep| symbol_kinds[dep] == "stream" }.each do |stream_name|
            fold_stream_stream_refs[stream_name] << node.fetch("name")
          end
          symbol_fragments[node.fetch("name")] = value_fragment
          symbol_kinds[node.fetch("name")] = "fold_stream"
          declarations << classified_decl(node, node_fragment, deps, []).merge(stream_value_fragment_metadata(value_fragment))
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
        when "intent"
          # PROP-045: intent descriptor — no symbol produced; collected below for OOF-INTENT3 check.
          nil
        end
      end

      diagnostics.concat(stream_missing_window_oofs(fold_stream_stream_refs, window_declarations))
      diagnostics.concat(evidence_gate_oofs(contract, sample_input))

      # PROP-045: extract intent_text; emit OOF-INTENT3 on duplicate
      intent_nodes = contract.fetch("body").select { |n| n.fetch("kind", nil) == "intent" }
      if intent_nodes.length > 1
        diagnostics << oof(
          "OOF-INTENT3",
          "contract '#{contract.fetch("name")}' declares 'intent' more than once; only the first is used",
          contract.fetch("name")
        )
      end
      contract_intent_text = intent_nodes.first&.fetch("text", nil)

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

      # LANG-EFFECT-SURFACE-RECEIPT-FAILURE-P1: OOF-M6 — receipt/failure placement.
      # Legal on effect/privileged/irreversible (full Effect Surface) and observed
      # (ch12 allows receipt/failure for the observation result). Refused on pure:
      # a pure contract has no external consequence to receipt or fail.
      # LANG-EFFECT-SURFACE-IDEMPOTENCY-P2: idempotency is additionally refused on
      # observed — it governs retry of MUTATIONS; an observation has no mutation
      # to dedupe (machine evidence keys idempotency to write effects).
      effect_surface_meta.each do |meta_kind, nodes|
        if modifier == "pure" && nodes.any?
          diagnostics << oof(
            "OOF-M6",
            "pure contract '#{contract.fetch("name")}' cannot declare '#{meta_kind}' " \
            "Effect Surface metadata; use 'effect' or 'observed' modifier",
            contract.fetch("name")
          )
        end
        if meta_kind == "idempotency" && modifier == "observed" && nodes.any?
          diagnostics << oof(
            "OOF-M6",
            "observed contract '#{contract.fetch("name")}' cannot declare 'idempotency'; " \
            "idempotency governs mutation retry and requires an effect-family modifier",
            contract.fetch("name")
          )
        end
        # LANG-EFFECT-SURFACE-AFFECTS-P5: affects names a MUTATION target — an
        # observation mutates nothing, so observed is refused like pure.
        if meta_kind == "affects" && modifier == "observed" && nodes.any?
          diagnostics << oof(
            "OOF-M6",
            "observed contract '#{contract.fetch("name")}' cannot declare 'affects'; " \
            "affects names a mutation target and requires an effect-family modifier",
            contract.fetch("name")
          )
        end
        # LANG-EFFECT-SURFACE-COMPENSATION-P22 / REVERSIBILITY-P25: compensation
        # and reversibility describe a MUTATION — observed is refused like pure.
        if %w[compensation no_compensation reversibility].include?(meta_kind) && modifier == "observed" && nodes.any?
          diagnostics << oof(
            "OOF-M6",
            "observed contract '#{contract.fetch("name")}' cannot declare '#{meta_kind}'; " \
            "compensation reverses a mutation and requires an effect-family modifier",
            contract.fetch("name")
          )
        end
        # LANG-EFFECT-SURFACE-AUTHORITY-PARSER-P10: authority gates mutation
        # execution; observed is refused like pure.
        if meta_kind == "authority" && modifier == "observed" && nodes.any?
          diagnostics << oof(
            "OOF-M6",
            "observed contract '#{contract.fetch("name")}' cannot declare 'authority'; " \
            "authority gates mutation execution and requires an effect-family modifier",
            contract.fetch("name")
          )
        end
        if nodes.length > 1
          diagnostics << oof(
            "OOF-M6",
            "contract '#{contract.fetch("name")}' declares '#{meta_kind}' more than once; " \
            "the Effect Surface carries exactly one #{meta_kind} type",
            contract.fetch("name")
          )
        end
      end

      # LANG-EFFECT-SURFACE-COMPENSATION-P22: `compensation` and `no_compensation`
      # are mutually exclusive — a contract cannot both name a compensator and
      # explicitly waive one.
      if effect_surface_meta["compensation"].any? && effect_surface_meta["no_compensation"].any?
        diagnostics << oof(
          "OOF-M6",
          "contract '#{contract.fetch("name")}' declares both 'compensation' and " \
          "'no_compensation'; the Effect Surface carries exactly one compensation decision",
          contract.fetch("name")
        )
      end

      # LANG-EFFECT-SURFACE-REVERSIBILITY-P25: the ONE specified contradiction —
      # the ch12 scale defines :irreversible ("No compensation is possible") and
      # :destructive; declaring either together with `compensation <Ref>` is
      # self-contradictory. The soft cases (reversible/compensatable/refundable +
      # no_compensation = capable-but-waived) are deliberately NOT checked.
      rev_node = effect_surface_meta["reversibility"].first
      if rev_node && %w[irreversible destructive].include?(rev_node.fetch("value", "")) &&
         effect_surface_meta["compensation"].any?
        diagnostics << oof(
          "OOF-M6",
          "contract '#{contract.fetch("name")}' declares reversibility " \
          ":#{rev_node.fetch("value")} (no compensation possible) together with " \
          "'compensation'; the scale definition contradicts the named compensator",
          contract.fetch("name")
        )
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
          # LANG-PROFILE-IDEMPOTENCY-RETRY-P31 (PROP-048): OOF-PROF4 — a
          # retry-enabled profile bound to a contract declaring `idempotency none`
          # is a declared contradiction (a retried effect without an idempotency
          # key can double-apply). Compile-time POLICY only (Covenant P10); grants
          # nothing at runtime. Hard error per P30. `key`/`natural` are safe;
          # `retry: disabled` / absent retry / no `via` impose no constraint.
          if resolved.fetch("retry", nil) == "enabled"
            idem = declarations.find { |d| d.fetch("kind", "") == "idempotency" }
            if idem && idem.fetch("mode", nil) == "none"
              diagnostics << oof(
                "OOF-PROF4",
                "contract '#{contract.fetch("name")}' declares 'idempotency none' but binds " \
                "retry-enabled profile '#{via_profile}'; a retried effect without an idempotency " \
                "key can double-apply (declare 'idempotency key <expr>' or set the profile to " \
                "'retry: disabled')",
                contract.fetch("name")
              )
            end
          end
          # LANG-PROFILE-MAX-REVERSIBILITY-P32 (PROP-048): OOF-PROF5 — a bound
          # contract whose declared ch12 `reversibility` exceeds the profile's
          # `max_reversibility` ceiling. First place the reversibility scale
          # ORDERING is encoded (P25 deliberately left it un-encoded). Absent
          # ceiling ⇒ no constraint; absent contract reversibility ⇒ no violation
          # (P25 absence is null, not a default). Hard error per P30.
          profile_max_rev = resolved.fetch("max_reversibility", nil)
          if profile_max_rev
            rev_rank = { "reversible" => 0, "compensatable" => 1, "refundable" => 2,
                         "append_only" => 3, "irreversible" => 4, "destructive" => 5 }
            rev_decl = declarations.find { |d| d.fetch("kind", "") == "reversibility" }
            declared_rev = rev_decl && rev_decl.fetch("value", nil)
            if declared_rev && rev_rank.fetch(declared_rev, -1) > rev_rank.fetch(profile_max_rev, 99)
              diagnostics << oof(
                "OOF-PROF5",
                "contract '#{contract.fetch("name")}' declares reversibility ':#{declared_rev}' " \
                "which exceeds the maximum ':#{profile_max_rev}' permitted by profile " \
                "'#{via_profile}'",
                contract.fetch("name")
              )
            end
          end
          # LANG-PROFILE-ALLOWED-EFFECTS-P35 (PROP-048): OOF-PROF1 — a bound
          # contract whose Effect Surface `affects <scope> <target>` names a
          # system NOT in the profile's `allowed_effects` allow-list. An entry
          # `<scope>.<prefix>` permits an exact target or a dot-boundary prefix
          # (`external.payment_gateway` covers `payment_gateway.charge`). Absent
          # `allowed_effects` ⇒ no restriction; no `affects` clause ⇒ no
          # violation; empty list ⇒ allow nothing (lock-down). Hard error (P30).
          allowed = resolved.fetch("allowed_effects", nil)
          if allowed
            affects_decl = declarations.find { |d| d.fetch("kind", "") == "affects" }
            if affects_decl
              a_scope  = affects_decl.fetch("scope", nil)
              a_target = affects_decl.fetch("target", nil).to_s
              permitted = allowed.any? do |e|
                e.fetch("scope") == a_scope &&
                  (a_target == e.fetch("target_prefix") ||
                   a_target.start_with?(e.fetch("target_prefix") + "."))
              end
              unless permitted
                diagnostics << oof(
                  "OOF-PROF1",
                  "contract '#{contract.fetch("name")}' affects '#{a_scope} #{a_target}' " \
                  "which profile '#{via_profile}' does not permit (not in allowed_effects)",
                  contract.fetch("name")
                )
              end
            end
          end
          # LANG-PROFILE-REQUIRES-AUTHORITY-P41 (PROP-049): OOF-PROF2 — a bound
          # contract must DECLARE a ch12 `authority` clause whose role is among
          # the profile's `requires_authority` list. Missing authority clause, or
          # a declared role outside the required set ⇒ hard error. This is a
          # DECLARATION-CONSISTENCY check over source facts only (Covenant P10):
          # it resolves no roles, checks no passport, and GRANTS NOTHING at
          # runtime — the runtime authority line (ch12 authority_ref → host
          # AuthorityPolicy) is separate and HELD. Absent `requires_authority` ⇒
          # no constraint; no `via` ⇒ no constraint. v0 matches against the
          # contract's single declared role; multi-role "must declare ALL" is
          # deferred to a ch12 multi-authority-clause extension.
          required_roles = resolved.fetch("requires_authority", nil)
          if required_roles
            auth_decl = declarations.find { |d| d.fetch("kind", "") == "authority" }
            declared_role = auth_decl && auth_decl.fetch("ref", nil)
            if declared_role.nil?
              diagnostics << oof(
                "OOF-PROF2",
                "contract '#{contract.fetch("name")}' binds profile '#{via_profile}' which " \
                "requires authority #{required_roles.inspect} but declares no 'authority' clause",
                contract.fetch("name")
              )
            elsif !required_roles.include?(declared_role)
              diagnostics << oof(
                "OOF-PROF2",
                "contract '#{contract.fetch("name")}' declares authority '#{declared_role}', " \
                "not one of the roles #{required_roles.inspect} required by profile " \
                "'#{via_profile}'",
                contract.fetch("name")
              )
            end
          end
          # LANG-PROFILE-LOOP-CLASS-P42 (PROP-048): OOF-PROF3 — a bound contract
          # whose loop-class is not the one permitted by the profile's `loop:`.
          # The contract's loop-class(es) are LIVE source facts: modifier
          # `recursive`/`fuel_bounded`, and a `budgeted_loop` body decl. A contract
          # using no loop construct is unrestricted (nothing exceeds the ceiling).
          # `loop: none` ⇒ any loop construct violates. Absent `loop` ⇒ no
          # constraint; no `via` ⇒ no constraint. Hard error (P30). ch11's
          # aspirational finite_loop/convergent/service (Ch13 service contracts)
          # are HELD — the parser refuses them (OOF-PROF6), so they never reach here.
          permitted_loop = resolved.fetch("loop", nil)
          if permitted_loop
            contract_loop_classes = []
            contract_loop_classes << "recursive"    if modifier == "recursive"
            contract_loop_classes << "fuel_bounded"  if modifier == "fuel_bounded"
            contract_loop_classes << "budgeted"      if declarations.any? { |d| d.fetch("kind", "") == "budgeted_loop" }
            violating = contract_loop_classes.reject { |c| c == permitted_loop }
            unless violating.empty?
              diagnostics << oof(
                "OOF-PROF3",
                "contract '#{contract.fetch("name")}' uses loop class #{violating.inspect} " \
                "but profile '#{via_profile}' permits only '#{permitted_loop}'",
                contract.fetch("name")
              )
            end
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

      # PROP-039 OOF-R3: extract named decreases variant for TypeChecker gate.
      # Only applies to recursive contracts; fuel variant is exempt (auto-managed).
      decreases_variant_name = nil
      if modifier == "recursive"
        dv_node = contract.fetch("body").find { |n| n.fetch("kind") == "decreases" }
        if dv_node
          v = dv_node.fetch("variant", "")
          decreases_variant_name = v unless v == "fuel" || v.empty?
        end
      end

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
      result["decreases_variant"] = decreases_variant_name if decreases_variant_name
      # PROP-033/040: propagate via_profile and resolved profile_authority
      result["via_profile"]       = via_profile       if via_profile
      result["profile_authority"] = profile_authority  if profile_authority
      result["assumption_refs"]   = assumption_refs.uniq unless assumption_refs.empty?
      # LANG-TYPED-CONTRACT-REF-PROP-P3: propagate typed contract reference declarations
      result["contract_ref_declarations"] = contract_ref_declarations unless contract_ref_declarations.empty?
      # PROP-045: propagate contract-level intent_text
      result["intent_text"] = contract_intent_text if contract_intent_text
      result
    end

    def contract_fragment_for(declarations, diagnostics, modifier: "pure")
      # LANG-TYPED-CONTRACT-REF-PROP-P3: metadata-fragment declarations are transparent to fragment classification.
      behavior_decls = declarations.reject { |decl| decl.fetch("fragment_class") == "metadata" }
      return "oof" unless diagnostics.empty?
      return "core" if behavior_decls.all? { |decl| decl.fetch("fragment_class") == "core" }
      return "temporal" if behavior_decls.any? { |decl| decl.fetch("fragment_class") == "temporal" } &&
                           behavior_decls.none? { |decl| decl.fetch("fragment_class") == "oof" }
      return "stream" if behavior_decls.any? { |decl| decl.fetch("fragment_class") == "stream" } &&
                         behavior_decls.none? { |decl| decl.fetch("fragment_class") == "oof" }
      return "escape" if (modifier != "pure" || behavior_decls.any? { |decl| decl.fetch("fragment_class") == "escape" }) &&
                         behavior_decls.none? { |decl| decl.fetch("fragment_class") == "oof" }
      return "epistemic" if behavior_decls.any? { |decl| decl.fetch("fragment_class") == "epistemic" } &&
                            behavior_decls.none? { |decl| decl.fetch("fragment_class") == "oof" }

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

    def stream_value_fragment_metadata(value_fragment)
      {
        "node_fragment_class" => "stream",
        "value_fragment_class" => value_fragment,
        "required_capability" => "stream_input"
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
      when "form_invocation"
        expr.fetch("attrs", []).flat_map { |attr| expr_refs(attr.fetch("value")) } +
          expr.fetch("children", []).flat_map { |child| expr_refs(child) }
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
