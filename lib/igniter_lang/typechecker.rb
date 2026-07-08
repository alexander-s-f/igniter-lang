# frozen_string_literal: true

require "digest"

module IgniterLang
  class TypeChecker
    DEFAULT_VERSION = "typed-pass-executable-proof-v0"

    # ── igniter-string-core-units-and-pure-stdlib-boundary-v0 ─────────────────
    # Text stdlib function registry (v0).
    # arg_types: positional expected types. "Text" accepts both Text and String
    # (v0 compatibility rule: string literals from the parser type as "String").
    # return_type: "Collection[Text]" is the only parameterised return; all
    # others are simple type names handled by type_ir().
    TEXT_STDLIB_FNS = {
      "concat"          => { arg_types: %w[Text Text],              return_type: "Text" },
      "trim"            => { arg_types: %w[Text],                   return_type: "Text" },
      "contains"        => { arg_types: %w[Text Text],              return_type: "Bool" },
      "starts_with"     => { arg_types: %w[Text Text],              return_type: "Bool" },
      "ends_with"       => { arg_types: %w[Text Text],              return_type: "Bool" },
      "split"           => { arg_types: %w[Text Text],              return_type: "Collection[Text]" },
      "replace"         => { arg_types: %w[Text Text Text],         return_type: "Text" },
      "replace_all"     => { arg_types: %w[Text Text Text],         return_type: "Text" },
      "byte_length"     => { arg_types: %w[Text],                   return_type: "Integer" },
      "rune_length"     => { arg_types: %w[Text],                   return_type: "Integer" },
      "grapheme_length" => { arg_types: %w[Text],                   return_type: "Integer" },
      "byte_slice"      => { arg_types: %w[Text Integer Integer],   return_type: "Text" },
      "rune_slice"      => { arg_types: %w[Text Integer Integer],   return_type: "Text" },
      "grapheme_slice"  => { arg_types: %w[Text Integer Integer],   return_type: "Text" },
    }.freeze

    # ── PROP-041: T2 structural-size relation registry ─────────────────────────
    # Stdlib-certified entries: hardcoded, trust = stdlib_certified.
    # source = "compiler_builtin" is the canonical source string for stdlib entries.
    STDLIB_SIZE_REGISTRY = {
      ["Collection", "tail"] => { "trust" => "stdlib_certified", "source" => "compiler_builtin" },
      ["Collection", "rest"] => { "trust" => "stdlib_certified", "source" => "compiler_builtin" }
    }.freeze

    # Accessors that indicate numeric measures (T3 territory).
    # When a dotted-path variant uses one of these, route to OOF-R3, not OOF-R8.
    # Closed list in v1; not user-extensible.
    NUMERIC_ACCESSORS = %w[count length size total_count num_items num_elements].freeze

    # PROP-042 T3: Numeric measure builtins registry (v0 — exhaustive).
    # Only count(Collection[T]) is in v0.
    # size/length/Text measures deferred. User-defined measures deferred to v1.
    # NOT user-extensible in v0. Adding an entry requires a new PROP amendment.
    # NOT a full termination proof — numeric evidence with trust metadata only.
    NUMERIC_MEASURE_BUILTINS = {
      "count" => {
        "qualified_name" => "stdlib.collection.count",
        "input_type"     => "Collection",
        "return_type"    => "Integer",
        "trust"          => "stdlib_numeric_certified",
        "source"         => "compiler_builtin"
      }
    }.freeze

    # PROP-043: Map[String,V] stdlib function registry (v0 — exhaustive, not user-extensible).
    # Short source names → qualified SemanticIR names (same pattern as TEXT_STDLIB_FNS).
    # Adding an entry requires a new PROP amendment and P3+ authorization.
    MAP_STDLIB_FNS = {
      "map_get"        => { qualified_name: "stdlib.map.get",        arity: 2 },
      "map_has_key"    => { qualified_name: "stdlib.map.has_key",    arity: 2 },
      "map_from_pairs" => { qualified_name: "stdlib.map.from_pairs", arity: 1 },
      "map_empty"      => { qualified_name: "stdlib.map.empty",      arity: 0 },
    }.freeze

    # LANG-STDLIB-NUMERIC-TEXT-CONVERSION-P1: integer numeric/text conversion registry (v0 — exhaustive,
    # not user-extensible). Canonical SIR names live under stdlib.integer.* (consistent with the live
    # stdlib.integer.gt/lt/add ops). Recognized source aliases per fn: the bare name, stdlib.numeric.<name>,
    # and stdlib.integer.<name> — mirroring the stdlib.numeric.add | add | stdlib.integer.add alias family.
    # The SemanticIR fn is ALWAYS the qualified_name; a source alias never appears in SIR.
    #   parse_int(Text) -> Option[Integer]   total; None on malformed/overflow (base-10, optional leading '-').
    #   int_to_text(Integer) -> Text          total; no grouping/locale.
    #   modulo(Integer, Integer) -> Integer   divisor 0 = fail-closed operational error at runtime.
    # Adding an entry requires a PROP amendment + authorization.
    NUMERIC_STDLIB_FNS = {
      "parse_int"   => { qualified_name: "stdlib.integer.parse_int",   arg_types: %w[Text],            return_type: "Option[Integer]" },
      "int_to_text" => { qualified_name: "stdlib.integer.int_to_text", arg_types: %w[Integer],         return_type: "Text" },
      "modulo"      => { qualified_name: "stdlib.integer.modulo",      arg_types: %w[Integer Integer], return_type: "Integer" },
    }.freeze

    # Every recognized source spelling → canonical bare key. Three aliases per fn:
    # bare, stdlib.numeric.<name>, stdlib.integer.<name>.
    NUMERIC_STDLIB_ALIASES = NUMERIC_STDLIB_FNS.keys.each_with_object({}) do |bare, h|
      h[bare]                     = bare
      h["stdlib.numeric.#{bare}"] = bare
      h["stdlib.integer.#{bare}"] = bare
    end.freeze

    # LANG-STDLIB-OUTCOME-PROP-P3: stdlib.outcome helper registry (v0 — exhaustive, not user-extensible).
    # Source aliases → qualified SemanticIR canonical names. Follows MAP_STDLIB_FNS prefix pattern.
    # All 7 entries: arity 1, input Map[String,String] (or Unknown), pure, authority_surface: none.
    # SemanticIR fn is always the qualified_name; source alias never appears in SIR.
    # is_retryable and route are permanently closed (LANG-STDLIB-OUTCOME-PROP-P1 §6/§7).
    # Adding entries requires PROP amendment + P4+ authorization.
    OUTCOME_STDLIB_FNS = {
      "outcome_kind"                      => { qualified_name: "stdlib.outcome.kind",                      return_type: "String" },
      "outcome_is_denied"                 => { qualified_name: "stdlib.outcome.is_denied",                 return_type: "Bool"   },
      "outcome_is_unknown_external_state" => { qualified_name: "stdlib.outcome.is_unknown_external_state", return_type: "Bool"   },
      "outcome_is_timed_out"              => { qualified_name: "stdlib.outcome.is_timed_out",              return_type: "Bool"   },
      "outcome_is_system_error"           => { qualified_name: "stdlib.outcome.is_system_error",           return_type: "Bool"   },
      "outcome_is_query_error"            => { qualified_name: "stdlib.outcome.is_query_error",            return_type: "Bool"   },
      "outcome_is_partial_success"        => { qualified_name: "stdlib.outcome.is_partial_success",        return_type: "Bool"   },
    }.freeze

    # LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P1: stdlib.collection HOF registry (v0 — exhaustive).
    # Source aliases → qualified SemanticIR names. All pure/core/authority_surface:none.
    # map/filter/find/any/all: 2-arg (collection, lambda). count: 1-arg (collection).
    # No predicate-count in v0.
    # SemanticIR fn is always the qualified_name. Source alias never appears in SIR.
    # Adding entries requires PROP amendment + P4+ authorization.
    COLLECTION_HOF_FNS = {
      "map"      => { qualified_name: "stdlib.collection.map",      arity: 2, has_lambda: true  },
      "filter"   => { qualified_name: "stdlib.collection.filter",   arity: 2, has_lambda: true  },
      "count"    => { qualified_name: "stdlib.collection.count",    arity: 1, has_lambda: false },
      "find"     => { qualified_name: "stdlib.collection.find",     arity: 2, has_lambda: true  },
      "any"      => { qualified_name: "stdlib.collection.any",      arity: 2, has_lambda: true  },
      "all"      => { qualified_name: "stdlib.collection.all",      arity: 2, has_lambda: true  },
      # LANG-STDLIB-COLLECTION-FLATMAP-P3 (admitted by -FLATMAP-PROP-P1): flat_map(Collection[A],
      # A -> Collection[B]) -> Collection[B]. The result is ONE-LEVEL unwrapped (the lambda body's
      # collection type itself), never re-wrapped as Collection[Collection[B]].
      "flat_map" => { qualified_name: "stdlib.collection.flat_map", arity: 2, has_lambda: true  },
    }.freeze

    # LANG-STDLIB-COLLECTION-FIRST-LAST-P2: source aliases for Rust-parity
    # collection edge readers. These intentionally do not share HOF diagnostics:
    # Rust currently returns Option[Unknown] on malformed/non-inferable inputs.
    COLLECTION_FIRST_LAST_FNS = {
      "first" => { qualified_name: "stdlib.collection.first" },
      "last"  => { qualified_name: "stdlib.collection.last"  },
    }.freeze

    # LANG-SUMTYPE-CONSTRUCT-MATCH-P3: sealed built-in sumtypes.
    # Registry shape mirrors the 3-level user variant_shapes (variant→arm→field→type)
    # but is held SEPARATELY from @variant_shapes so it is NOT emitted into the
    # SemanticIR `variant_env` (which must stay user-variant-only for byte-parity).
    # Field types are Unknown placeholders: the concrete payload type for a match
    # binding is substituted from the subject's params at match time
    # (sealed_arm_field_types); constructors set the concrete resolved_type directly.
    # Payload labels are locked to `value` / `error` (P2 closure).
    SEALED_VARIANT_SHAPES = {
      "Option" => {
        "Some" => { "value" => { "name" => "Unknown", "params" => [] } },
        "None" => {},
      },
      "Result" => {
        "Ok"  => { "value" => { "name" => "Unknown", "params" => [] } },
        "Err" => { "error" => { "name" => "Unknown", "params" => [] } },
      },
    }.freeze

    # Source aliases admitted as sealed constructors (function-form only, P3 v0).
    SEALED_CONSTRUCTORS = %w[some none ok err].freeze

    # PROP-042 T3: Matches "fn_name(arg_name)" — the T3 function-call decreases form.
    # Produced by parser.rb parse_decreases_decl when lparen follows the first identifier.
    T3_CALL_FORM_RE = /\A(\w+)\((\w+)\)\z/

    # LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3 (board G4: gated activation):
    # `optional_fields: true` activates `f : T?` ≡ `f : Option[T]` semantics
    # (omit→None injection, T→Some auto-wrap, Option[T] passthrough) per the
    # PROVED PROP-P2 design. Default OFF — with the gate off, type_shapes drop
    # the optional flag exactly as before and behavior is byte-identical.
    # LANG-EFFECT-SURFACE-REQUIRED-FIELDS-P28 (gated completeness, board follow-up
    # to P26): `required_effect_surface: true` emits OOF-M17 *warnings* for
    # effect-family contracts that omit a required Effect Surface field. Default
    # OFF — with the gate off, no OOF-M17 is ever produced and warning/error sets
    # are byte-identical to before. Warning-only in v0; hard-error / default-ON /
    # profile-policy are explicitly out of scope.
    def initialize(typechecker_version: DEFAULT_VERSION, optional_fields: false,
                   required_effect_surface: false)
      @typechecker_version = typechecker_version
      @optional_fields = optional_fields
      @required_effect_surface = required_effect_surface
    end

    def typecheck(classified_program, cross_module_registry: {}, per_module_imports: {}, per_contract_module: {})
      @type_shapes    = type_shapes(classified_program)
      @variant_shapes = variant_shapes(classified_program)  # PROP-044 P5
      @assumption_registry = classified_program.fetch("assumption_registry", [])
      @type_shapes["Assumption"] = assumption_shape if assumptions_present?(classified_program)
      # PROP-041: build T2 size-relation registry (stdlib + user-declared)
      @size_registry = build_size_registry(classified_program)
      @t2_context    = nil
      @t3_context    = nil  # PROP-042 T3
      @assumption_errors = assumption_errors_by_name(@assumption_registry)
      @olap_env = olap_env(classified_program.fetch("olap_points", []))
      @olap_errors = olap_declaration_errors(@olap_env)
      # LANG-TYPED-CONTRACT-REF-PROP-P3: build same-module contract registry for uses_contract resolution
      @same_module_registry = build_same_module_registry(classified_program)
      # LAB-RUBY-CALL-CONTRACT-PARITY-P3: build call_contract dispatch registry (separate from same_module_registry)
      @call_contract_registry = build_call_contract_registry(classified_program)
      @classified_module = classified_program.fetch("module", nil)
      # LANG-TYPED-CONTRACT-REF-PROP-P5: cross-module resolution state (per-call, not constructor)
      @cross_module_registry = cross_module_registry
      @per_module_imports = per_module_imports
      @per_contract_module = per_contract_module
      typed_contracts = classified_program.fetch("contracts").map do |contract|
        typecheck_contract(contract)
      end
      cycle_errors = detect_uses_cycles(typed_contracts)
      entrypoint_errors, resolved_entrypoint = validate_entrypoint(classified_program)

      # PROP-044-P9: OOF-KIND6 — reserved __* field names in module-level declarations.
      module_reserved_errors = []
      classified_program.fetch("type_declarations", []).each do |type_decl|
        type_decl.fetch("fields", []).each do |field|
          fname = field.fetch("name", "")
          next unless fname.start_with?("__")
          module_reserved_errors << oof("OOF-KIND6",
            "Field '#{fname}' in type '#{type_decl.fetch("name")}' uses reserved compiler prefix '__' (compiler-owned variant runtime field)",
            type_decl.fetch("name"))
        end
      end
      classified_program.fetch("variant_declarations", []).each do |vd|
        vd.fetch("arms", []).each do |arm|
          arm.fetch("fields", []).each do |field|
            fname = field.fetch("name", "")
            next unless fname.start_with?("__")
            module_reserved_errors << oof("OOF-KIND6",
              "Field '#{fname}' in variant '#{vd.fetch("name")}' arm '#{arm.fetch("name")}' uses reserved compiler prefix '__'",
              vd.fetch("name"))
          end
        end
      end

      # OOF-L4: per-SCC rule — every member of a nontrivial SCC must declare `decreases fuel`.
      # Replaces the self-only fn_self_recursive? check (LAB-FUNCTION-RECURSION-P3 ACCEPT decision).
      function_errors = []
      fns = classified_program.fetch("functions", [])
      unless fns.empty?
        fn_names_set = fns.map { |f| f.fetch("name") }.to_set
        fn_adj = fns.to_h do |f|
          [f.fetch("name"), fn_extract_all_calls(f.fetch("body", {}), fn_names_set)]
        end
        sccs = tarjan_sccs(fns.map { |f| f.fetch("name") }, fn_adj)
        fn_map = fns.to_h { |f| [f.fetch("name"), f] }
        sccs.each do |scc|
          is_nontrivial = scc.length > 1 || (fn_adj[scc.first] || []).include?(scc.first)
          next unless is_nontrivial
          scc.sort.each do |fn_name|
            f = fn_map[fn_name]
            unless f.fetch("decreases", nil) == "fuel"
              function_errors << oof("OOF-L4",
                "Recursive function '#{fn_name}' must specify 'decreases fuel'",
                fn_name)
            end
          end
        end
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
        "type_errors" => typed_contracts.flat_map { |contract| contract.fetch("type_errors") } + module_reserved_errors + entrypoint_errors + cycle_errors + function_errors + shape_conformance_errors(classified_program),
        "semantic_ir_ref" => nil
      }
      result["entrypoint"] = resolved_entrypoint if resolved_entrypoint
      result["assumption_registry"] = @assumption_registry unless @assumption_registry.empty?
      result["variant_env"] = @variant_shapes unless @variant_shapes.empty?  # PROP-044 P5
      result["olap_points"] = @olap_env.values.map { |decl| decl.fetch("semantic_node") } unless @olap_env.empty?
      type_warnings = typed_contracts.flat_map { |contract| contract.fetch("type_warnings", []) }
      result["type_warnings"] = type_warnings unless type_warnings.empty?
      # PROP-045: propagate module-level intent_text
      module_intent = classified_program.fetch("intent_text", nil)
      result["intent_text"] = module_intent if module_intent
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
          # LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3 (gate ON only): `f : T?` desugars
          # to shape type Option[T] carrying `optional: true`. Gate OFF keeps the
          # exact legacy line — the optional flag is dropped, byte-identical.
          if @optional_fields && field.fetch("optional", false)
            fields[field.fetch("name")] = optional_field_type_ir(field.fetch("type_annotation"))
          else
            fields[field.fetch("name")] = type_ir(field.fetch("type_annotation"))  # PROP-043 C1: preserve Map[K,V] params
          end
        end
      end
    end

    # LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3: shape IR for a declared-optional field.
    # `Option[T]` + `optional: true` flag (PROP-P2 Q1 — no other metadata invented).
    # The flag can only appear in shapes when the gate is ON, so downstream rules
    # (missing-field exemption, auto-wrap) key off the flag, not the gate.
    def optional_field_type_ir(annotation)
      option_type_ir(type_ir(annotation)).merge("optional" => true)
    end

    # True when a SHAPE field type IR is a declared-optional field (gate-ON only).
    def optional_shape_field?(tir)
      tir.is_a?(Hash) && tir.fetch("optional", false) == true
    end

    # Inner T of a declared-optional Option[T] shape field.
    def optional_inner_type(tir)
      type_ir(tir.fetch("params", []).fetch(0, "Unknown"))
    end

    # LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3: TC-synthesized option_construct nodes.
    # Unlike variant_construct there is NO source syntax that produces these —
    # they originate in the typechecker at record-literal construction sites
    # (omit → arm "none", raw-T value → arm "some" auto-wrap). Layout is modeled
    # on variant_construct (kind/arm/resolved_type) with value+inner_type payload.
    def option_some_node(typed_value, inner_type)
      typed_expr("option_construct", option_type_ir(inner_type),
                 typed_value.fetch("deps", []),
                 "arm" => "some", "inner_type" => inner_type, "value" => typed_value)
    end

    def option_none_node(inner_type)
      typed_expr("option_construct", option_type_ir(inner_type), [],
                 "arm" => "none", "inner_type" => inner_type)
    end

    # PROP-044 P5: 3-level store: variant_name → arm_name → field_name → type_ir
    def variant_shapes(classified_program)
      classified_program.fetch("variant_declarations", []).each_with_object({}) do |variant, vshapes|
        vshapes[variant.fetch("name")] =
          variant.fetch("arms", []).each_with_object({}) do |arm, arms|
            arms[arm.fetch("name")] =
              arm.fetch("fields", []).each_with_object({}) do |field, fields|
                fields[field.fetch("name")] = type_ir(field.fetch("type_annotation"))
              end
          end
      end
    end

    def variant_type?(name)
      @variant_shapes.key?(name) || sealed_builtin?(name)
    end

    # LANG-SUMTYPE-CONSTRUCT-MATCH-P3: admission for sealed built-in sumtypes.
    # Registration in SEALED_VARIANT_SHAPES IS the OOF-KIND4 relax: only Option /
    # Result are admitted to the variant match path; arbitrary named types remain
    # rejected. User variants take precedence (a user `variant Option {…}` would
    # shadow the built-in via @variant_shapes).
    def sealed_builtin?(name)
      !@variant_shapes.key?(name) && SEALED_VARIANT_SHAPES.key?(name)
    end

    # Concrete payload types for a sealed match arm, substituted from the subject's
    # type params: Option[P0] → Some{value:P0}; Result[P0,P1] → Ok{value:P0},
    # Err{error:P1}. Missing params degrade to Unknown.
    def sealed_arm_field_types(subject_type_ir, arm_name)
      params = subject_type_ir.fetch("params", [])
      p0 = params.fetch(0, type_ir("Unknown"))
      p1 = params.fetch(1, type_ir("Unknown"))
      case [type_name(subject_type_ir), arm_name]
      when %w[Option Some] then { "value" => p0 }
      when %w[Result Ok]   then { "value" => p0 }
      when %w[Result Err]  then { "error" => p1 }
      else {}
      end
    end

    def validate_entrypoint(classified_program)
      entrypoint = classified_program.fetch("entrypoint", nil)
      return [[], nil] unless entrypoint

      target = entrypoint.fetch("target", "")
      contracts = classified_program.fetch("contracts")
      target_contract = contracts.find do |contract|
        target == contract.fetch("name") || target == contract.fetch("contract_id")
      end

      if target_contract
        return [[], entrypoint.merge(
          "kind" => "entrypoint_decl",
          "resolved_contract" => target_contract.fetch("name"),
          "resolved_contract_id" => target_contract.fetch("contract_id"),
          "contract_fragment_class" => target_contract.fetch("fragment_class")
        )]
      end

      if @type_shapes.key?(target)
        return [[oof("OOF-EP5", "entrypoint target '#{target}' is a type, not a contract", target)], nil]
      end

      available = contracts.flat_map { |contract| [contract.fetch("name"), contract.fetch("contract_id")] }.uniq.sort
      [[oof(
        "OOF-EP2",
        "entrypoint target '#{target}' does not resolve to a contract",
        target
      ).merge("available_contracts" => available)], nil]
    end

    def variant_arms(name)
      return @variant_shapes[name] if @variant_shapes.key?(name)
      SEALED_VARIANT_SHAPES.fetch(name, {})
    end

    def find_variant_for_arm(arm_name)
      @variant_shapes.each { |vname, arms| return vname if arms.key?(arm_name) }
      nil
    end

    def typecheck_contract(classified_contract)
      declared_oofs = classified_contract.fetch("oof_log")
      assumption_refs = classified_contract.fetch("assumption_refs", [])
      type_errors = declared_oofs + @olap_errors + assumption_refs.flat_map { |name| @assumption_errors.fetch(name, []) }
      type_warnings = []
      symbol_types = {}
      typed_decls = []
      invariant_effects = []  # [{"name" => ..., "effect" => "warns"|"uncertain"|"metric"}] for output propagation

      # PROP-039 gate 5: recur() context for validation
      contract_modifier = classified_contract.fetch("modifier", "pure")
      contract_name_str = classified_contract.fetch("name")
      @current_contract_name = contract_name_str  # LAB-RUBY-CALL-CONTRACT-PARITY-P3: self-recursion guard
      # PROP-050/P46: `convergent` is recur-authorized like `fuel_bounded` —
      # convergent iteration runs via recur(), fuel-capped by max_steps; it has no
      # `decreases` variant, so OOF-R3 (structural decrease) does not apply.
      recur_authorized  = %w[recursive fuel_bounded convergent].include?(contract_modifier)
      all_decls = classified_contract.fetch("declarations")
      recur_inputs = all_decls.select { |d| d.fetch("kind","") == "input" }
      recur_outputs = all_decls.select { |d| d.fetch("kind","") == "output" }

      # PROP-039 OOF-R3 / PROP-041 T2 / PROP-042 T3: decreases_variant — extracted
      # by classifier, nil for fuel/fuel_bounded. Dispatch priority:
      #   function-call "fn(arg)"  → T3 (PROP-042)
      #   dotted-path  "sub.field" → T2 (PROP-041)
      #   simple-ident "n"         → T1 (PROP-039)
      @t2_context       = nil
      @t3_context       = nil  # PROP-042 T3
      decreases_variant = classified_contract.fetch("decreases_variant", nil)
      if decreases_variant && T3_CALL_FORM_RE.match?(decreases_variant)
        # PROP-042 T3: function-call form dispatch (count(items) etc.)
        # Returns nil to clear variant from @recur_context.
        decreases_variant = handle_t3_variant(
          decreases_variant, classified_contract, type_errors, contract_name_str
        )
      elsif decreases_variant && decreases_variant.include?(".")
        # PROP-041: T2 structural-size dispatch (numeric → OOF-R3; registered → T2;
        # missing → OOF-R8). Returns nil to clear variant from @recur_context.
        decreases_variant = handle_t2_variant(
          decreases_variant, classified_contract, type_errors, contract_name_str
        )
      end

      # PROP-043: @output_type_hints — pre-scan output declarations whose type_annotation
      # names a known named Record type in @type_shapes. Used by infer_record_literal to
      # resolve { field: value } literals to a named Record type and validate field shapes.
      # Only named Records (user-declared, present in @type_shapes) receive hints.
      # Map/Collection/primitive types are excluded — they are not @type_shapes entries.
      @output_type_hints = {}
      all_decls.select { |d| d.fetch("kind", "") == "output" }.each do |od|
        ann = od.fetch("type_annotation", nil)
        next unless ann
        tn = ann.is_a?(Hash) ? ann.fetch("name", nil) : ann.to_s
        @output_type_hints[od.fetch("name")] = type_ir(ann) if @type_shapes.key?(tn)
      end

      # LANG-SUMTYPE-CONSTRUCT-MATCH-P3: expected-type hints for sealed constructors.
      # Pre-scan output/compute decls annotated Option[...] / Result[...]; keyed by
      # name (output and its producing compute share a name). Read by
      # infer_sealed_construct to recover the param none()/ok()/err() cannot infer
      # from their arguments. Held separately so record-literal hint behaviour and
      # the emitted SIR are untouched.
      @sealed_output_hints = {}
      all_decls.each do |d|
        next unless %w[output compute].include?(d.fetch("kind", ""))
        ann = d.fetch("type_annotation", nil)
        next unless ann
        tn = ann.is_a?(Hash) ? ann.fetch("name", nil) : ann.to_s
        @sealed_output_hints[d.fetch("name")] = type_ir(ann) if %w[Option Result].include?(tn)
      end

      # LANG-SUMTYPE-COLLECT-P3: expected element-type hints for filter_map output
      # context (fallback B2). Pre-scan output/compute decls annotated Collection[U];
      # keyed by name. Read by infer_filter_map_call to recover U when a parametric
      # `match` callback collapses to bare Option, and to temp-install an Option[U]
      # sealed hint while inferring the callback body so none()/some() resolve vs U.
      @collection_output_hints = {}
      all_decls.each do |d|
        next unless %w[output compute].include?(d.fetch("kind", ""))
        ann = d.fetch("type_annotation", nil)
        next unless ann
        tn = ann.is_a?(Hash) ? ann.fetch("name", nil) : ann.to_s
        @collection_output_hints[d.fetch("name")] = element_type_from_collection(type_ir(ann)) if tn == "Collection"
      end

      # PROP-043: OOF-MAP1/2/3 — check all declarations for Map annotation violations.
      # Runs before declarations.each so errors accumulate early and blocking_rule_present?
      # can suppress spurious downstream type mismatches.
      map_annotation_errors = []
      all_decls.each do |decl|
        next unless decl.key?("type_annotation")
        check_map_annotation(
          decl.fetch("type_annotation"),
          decl.fetch("name"),
          decl.fetch("kind", ""),
          map_annotation_errors
        )
      end
      type_errors.concat(map_annotation_errors)

      @recur_context = {
        authorized:         recur_authorized,
        modifier:           contract_modifier,
        input_names:        recur_inputs.map { |d| d.fetch("name") },
        output_count:       recur_outputs.length,
        output_type:        recur_outputs.length == 1 ? type_ir(recur_outputs.first.fetch("type_annotation", "Unknown")) : type_ir("Unknown"),
        decreases_variant:  decreases_variant,
      }
      @current_contract_refs = {}

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
        when "capability"
          # PROP-035: IO capability declarations — type is opaque to the compiler
          raw_type = decl.fetch("type_annotation", "IO.Capability")
          # Normalise all IO.* capability types to the IO.Capability sentinel
          type_name_str = raw_type.is_a?(Hash) ? (raw_type["name"] || "IO.Capability") : raw_type.to_s
          resolved_type = type_name_str.start_with?("IO.") ? type_ir("IO.Capability") : type_ir(type_name_str)
          symbol_types[decl.fetch("name")] = resolved_type
          typed_decls << typed_decl(decl, resolved_type, nil, [])
        when "effect_binding"
          # PROP-035: effect surface binding — structurally typed as Unit
          type = type_ir("Unit")
          symbol_types[decl.fetch("name")] = type
          typed_decls << typed_decl(decl, type, nil, decl.fetch("deps", []))
        when "affects"
          # LANG-EFFECT-SURFACE-AFFECTS-P5: Effect Surface metadata — pure
          # declaration (scope + qualified target name); no type resolution needed
          # (the target names an EXTERNAL/INTERNAL system, not a language type).
          typed_decls << typed_decl(decl, type_ir("Unit"), nil, [])
                           .merge("scope" => decl.fetch("scope"), "target" => decl.fetch("target"))
        when "compensation"
          # LANG-EFFECT-SURFACE-COMPENSATION-P22: the ref must name a same-module
          # contract (an unresolvable compensator is a silent lie the compiler CAN
          # catch — OOF-M15, fail-closed). Declaration only: no authority, no
          # host binding, no execution.
          ref = decl.fetch("contract_ref")
          unless @same_module_registry.key?(ref)
            type_errors << oof(
              "OOF-M15",
              "compensation ref '#{ref}' names no contract in this module",
              "compensation"
            )
          end
          typed_decls << typed_decl(decl, type_ir("Unit"), nil, [])
                           .merge("contract_ref" => ref)
        when "no_compensation"
          # LANG-EFFECT-SURFACE-COMPENSATION-P22: explicit waiver (≠ absence).
          typed_decls << typed_decl(decl, type_ir("Unit"), nil, [])
        when "reversibility"
          # LANG-EFFECT-SURFACE-REVERSIBILITY-P25: pure metadata — the scale value
          # was validated at parse time (OOF-M16); nothing to resolve.
          typed_decls << typed_decl(decl, type_ir("Unit"), nil, [])
                           .merge("value" => decl.fetch("value"))
        when "authority"
          # LANG-EFFECT-SURFACE-AUTHORITY-PARSER-P10: declared authority intent —
          # a bare role symbol resolved HOST-side (never by the compiler).
          typed_decls << typed_decl(decl, type_ir("Unit"), nil, [])
                           .merge("ref" => decl.fetch("ref"))
        when "idempotency"
          # LANG-EFFECT-SURFACE-IDEMPOTENCY-P2: Effect Surface metadata. Mode "key"
          # carries an expression typed with the normal inference path (unknown
          # refs/type errors fail closed exactly like a compute expression);
          # "natural"/"none" carry no expression. Metadata itself types as Unit.
          mode = decl.fetch("mode", "none")
          typed_expr = nil
          if mode == "key" && decl.key?("expr")
            typed_expr = infer_expr(decl.fetch("expr"), symbol_types, type_errors, type_warnings, "idempotency")
          end
          typed_decls << typed_decl(decl, type_ir("Unit"), typed_expr, [])
                           .merge("mode" => mode)
        when "write"
          # LANG-CH13-WRITE-EVIDENCE-P60 (§13.6): the value is typed via the normal
          # inference path; each MANDATORY `evidence` ref must resolve to a declared
          # local symbol (unresolved ⇒ OOF-W2 — the write cites evidence that does
          # not exist, a silent lie the compiler catches, fail-closed). The store is
          # a bare target ident (v0 — external, not resolved). Declaration only: the
          # append + lifecycle:audit are RUNTIME (write.rs, HELD).
          value_expr = decl.key?("value") ?
            infer_expr(decl.fetch("value"), symbol_types, type_errors, type_warnings, "write") : nil
          decl.fetch("evidence", []).each do |ref|
            next if symbol_types.key?(ref)
            type_errors << oof(
              "OOF-W2",
              "write to '#{decl.fetch("store", "?")}' cites evidence '#{ref}' which is not a " \
              "declared symbol in this contract",
              "write"
            )
          end
          typed_decls << typed_decl(decl, type_ir("Unit"), value_expr, [])
                           .merge("store" => decl.fetch("store", nil), "evidence" => decl.fetch("evidence", []))
        when "invoke"
          # PROP-050 / LAB-EFFECT-CALL-V0-P3 (S1): effect-contract call —
          # OOF-EC1/EC2/EC3/EC4-matrix/EC5 + result binding. See typecheck_invoke.
          typed_decls << typecheck_invoke(decl, contract_modifier, all_decls,
                                          symbol_types, type_errors, type_warnings)
        when "receipt", "failure"
          # LANG-EFFECT-SURFACE-RECEIPT-FAILURE-P1: Effect Surface metadata — the
          # referenced type must resolve (declared record/variant or builtin scalar);
          # an unresolvable type fails closed with OOF-M10.
          raw   = decl.fetch("type_annotation", "Unknown")
          tname = raw.is_a?(Hash) ? (raw["name"] || "Unknown") : raw.to_s
          unless @type_shapes.key?(tname) || @variant_shapes.key?(tname) ||
                 EFFECT_SURFACE_BUILTIN_TYPES.include?(tname)
            type_errors << oof(
              "OOF-M10",
              "#{decl.fetch("kind")} declares unknown type '#{tname}'; declare it as a " \
              "type/variant in this module or use a builtin",
              decl.fetch("kind")
            )
          end
          type = type_ir(raw)
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
        when "uses_contract"
          # LANG-TYPED-CONTRACT-REF-PROP-P3: resolve typed contract reference.
          # Does NOT enter symbol_types — not a local symbol binding.
          typed_ref = typecheck_uses_contract(decl, contract_name_str, type_errors)
          register_current_contract_ref(typed_ref)
          typed_decls << typed_ref
        when "invariant"
          # TINV-1/2/3: Resolve predicate_ref, validate overridable_with, compute output_effect
          check_invariant(decl, symbol_types, type_errors, invariant_effects)
          typed_decls << typed_decl_invariant(decl, symbol_types)
        when "compute"
          name = decl.fetch("name")
          temp_hint_installed = false
          if decl["type_annotation"] && decl.fetch("expr", {}).fetch("kind", nil) == "record_literal"
            declared_type = type_ir(decl["type_annotation"])
            tn = type_name(declared_type)
            if @type_shapes.key?(tn) && !@output_type_hints.key?(name)
              @output_type_hints[name] = declared_type
              temp_hint_installed = true
            end
          end
          begin
            typed_expr = infer_expr(decl.fetch("expr"), symbol_types, type_errors, type_warnings, name)
          ensure
            @output_type_hints.delete(name) if temp_hint_installed
          end
          validate_declared_olap_type(decl, typed_expr, type_errors)

          inferred_type = typed_expr.fetch("resolved_type")
          bind_type = if decl["type_annotation"]
            expected_type = type_ir(decl["type_annotation"])
            if unknown_or_unknown_bearing?(inferred_type)
              expected_type
            elsif structurally_assignable?(inferred_type, expected_type)
              inferred_type
            else
              type_errors << oof("OOF-TY0",
                "Binding type mismatch: declared #{type_display(expected_type)}, got #{type_display(inferred_type)}",
                decl.fetch("name"))
              expected_type
            end
          else
            inferred_type
          end

          symbol_types[decl.fetch("name")] = bind_type
          typed_decls << typed_decl(decl, bind_type, typed_expr, typed_expr.fetch("deps"))
        when "output"
          expected = type_ir(decl.fetch("type_annotation"))
          actual = symbol_types.fetch(decl.fetch("name"), type_ir("Unknown"))
          unless structurally_assignable?(actual, expected) || blocking_rule_present?(type_errors)
            type_errors << structural_mismatch(expected, actual, decl.fetch("name"))
          end
          # TINV-4: propagate invariant output effects to output nodes
          typed_decls << typed_decl_output(decl, expected, invariant_effects)
        when "for_loop"
          # PROP-039 gate 4: FiniteLoop — source must be Collection[T]
          source_name = decl.fetch("source")
          source_type = symbol_types.fetch(source_name, type_ir("Unknown"))
          unless type_name(source_type) == "Collection" || type_name(source_type) == "Unknown"
            type_errors << oof(
              "OOF-L1",
              "for loop '#{decl.fetch("name")}' source '#{source_name}' must be " \
              "Collection[T], got #{type_name(source_type)}",
              decl.fetch("name")
            )
          end
          # PROP-039 gate 8: body scope validation
          item_type = element_type_from_collection(source_type)
          item_name = decl.fetch("item")
          type_errors.concat(check_loop_body(decl, symbol_types, item_name, item_type))
          # Pass loop-specific fields + typed body to typed_decl for SemanticIR lowering
          td = typed_decl(decl, type_ir("Unit"), nil, decl.fetch("deps", []))
          td["source"]    = source_name
          td["item"]      = item_name
          td["item_type"] = type_name(item_type)
          td["body"]      = typed_loop_body(decl, symbol_types, item_name, item_type)
          typed_decls << td
        when "budgeted_loop"
          # PROP-039 gate 4: BudgetedLocalLoop — max_steps is static (enforced by parser);
          # source validated at classify time. TypeChecker just passes through.
          # PROP-039 gate 8: body scope validation
          source_name = decl.fetch("source")
          source_type = symbol_types.fetch(source_name, type_ir("Unknown"))
          item_type   = element_type_from_collection(source_type)
          item_name   = decl.fetch("item")
          type_errors.concat(check_loop_body(decl, symbol_types, item_name, item_type))
          # Pass loop-specific fields + typed body to typed_decl for SemanticIR lowering
          td = typed_decl(decl, type_ir("Unit"), nil, decl.fetch("deps", []))
          td["source"]    = source_name
          td["item"]      = item_name
          td["item_type"] = type_name(item_type)
          td["max_steps"] = decl.fetch("max_steps") if decl.key?("max_steps")
          td["body"]      = typed_loop_body(decl, symbol_types, item_name, item_type)
          typed_decls << td
        when "lead"
          # PROP-039 gate 8: lead is only valid inside a loop body; here it is at contract level
          type_errors << oof(
            "OOF-L5",
            "lead declaration '#{decl.fetch("name")}' is only valid inside a loop body",
            decl.fetch("name")
          )
        end
      end

      # LANG-EFFECT-SURFACE-COMPENSATION-P22: OOF-M3 as WARN (the ch12 §12.5
      # target severity) — an `irreversible` contract that neither names a
      # compensation nor explicitly waives one (`no_compensation`) gets a
      # warning, not a hard failure. First target-table row to go live.
      if contract_modifier == "irreversible"
        has_comp = typed_decls.any? { |d| %w[compensation no_compensation].include?(d.fetch("kind")) }
        unless has_comp
          type_warnings << oof(
            "OOF-M3",
            "irreversible contract '#{classified_contract.fetch("name")}' declares neither " \
            "'compensation <ContractName>' nor 'no_compensation'; declare or explicitly waive one",
            classified_contract.fetch("name")
          ).merge("severity" => "warning")
        end
      end

      # LANG-EFFECT-SURFACE-REQUIRED-FIELDS-P28: gated completeness warnings.
      # OOF-M17 (fresh; NOT the PROP-035 structural OOF-M2) fires only under the
      # `required_effect_surface` gate, only for effect-family contracts, and only
      # at `warning` severity — a missing declared field is a completeness gap,
      # not an unsound program. `compensation` requiredness is NOT covered here:
      # it stays owned by the live OOF-M3 warn above (declared-or-waived semantics
      # differ from plain presence). `observed`/`pure` are outside enforcement.
      if @required_effect_surface && EFFECT_FAMILY_MODIFIERS.include?(contract_modifier)
        present = typed_decls.map { |d| d.fetch("kind") }.to_set
        REQUIRED_EFFECT_SURFACE_FIELDS.each do |field, modifiers|
          next unless modifiers.include?(contract_modifier)
          next if present.include?(field)
          type_warnings << oof(
            "OOF-M17",
            "#{contract_modifier} contract '#{classified_contract.fetch("name")}' declares no " \
            "'#{field}' Effect Surface field (required by ch12; declare it or leave the " \
            "completeness gate off)",
            classified_contract.fetch("name")
          ).merge("severity" => "warning")
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
      # PROP-033/040: propagate via_profile and resolved profile_authority
      via_profile       = classified_contract.fetch("via_profile", nil)
      profile_authority = classified_contract.fetch("profile_authority", nil)
      result["via_profile"]       = via_profile       if via_profile
      result["profile_authority"] = profile_authority if profile_authority
      result["assumption_refs"] = assumption_refs unless assumption_refs.empty?
      # LANG-TYPED-CONTRACT-REF-PROP-P3: propagate typed contract reference declarations
      contract_ref_decls = typed_decls.select { |d| d["kind"] == "uses_contract" }
      result["contract_ref_declarations"] = contract_ref_decls unless contract_ref_decls.empty?
      warnings = dedupe_errors(type_warnings)
      result["type_warnings"] = warnings unless warnings.empty?
      # PROP-039 OOF-R3: propagate clean (non-dotted) decreases variant for SemanticIR evidence
      clean_variant = @recur_context.fetch(:decreases_variant, nil)
      result["decreases_variant"] = clean_variant if clean_variant
      # PROP-045: propagate contract-level intent_text
      intent_text = classified_contract.fetch("intent_text", nil)
      result["intent_text"] = intent_text if intent_text
      # PROP-041 T2: propagate structural-size evidence for SemanticIR structural_size_v1 emission
      if @t2_context&.fetch(:kind) == :t2_pass
        result["decreases_variant_t2"]   = @t2_context[:dv]
        result["size_relation_evidence"] = @t2_context[:entry]
      end
      # PROP-042 T3: propagate numeric measure evidence for SemanticIR numeric_measure_v0 emission
      if @t3_context&.fetch(:kind) == :t3_pass
        result["decreases_variant_t3"]     = @t3_context[:dv]
        result["numeric_measure_evidence"] = @t3_context[:builtin].merge("arg" => @t3_context[:arg_name])
      end
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

    # LANG-TYPED-CONTRACT-REF-PROP-P3: build same-module contract registry for typed ref resolution.
    def build_same_module_registry(classified_program)
      classified_program.fetch("contracts").each_with_object({}) do |contract, reg|
        name = contract.fetch("name")
        inputs  = contract.fetch("declarations").select { |d| d.fetch("kind") == "input" }
        outputs = contract.fetch("declarations").select { |d| d.fetch("kind") == "output" }
        reg[name] = {
          "modifier"     => contract.fetch("modifier", "pure"),
          "input_count"  => inputs.size,
          "input_names"  => inputs.map { |d| d.fetch("name") },
          "input_types"  => inputs.map { |d| d.fetch("type_annotation", "Unknown") },
          "output_names" => outputs.map { |d| d.fetch("name") },
          "output_types" => outputs.map { |d| d.fetch("type_annotation", "Unknown") },
          "single_output_type" => outputs.size == 1 ? outputs[0].fetch("type_annotation", nil) : nil
        }
      end
    end

    # LAB-RUBY-CALL-CONTRACT-PARITY-P3: registry for call_contract dispatch.
    # Maps contract_name → entry with modifier, input_count, single_output_type/name.
    # Separate from @same_module_registry (which is authoritative for uses_contract).
    # LANG-PACKAGE-CONTRACT-IDENTITY-P2 (FRUT-P08): the registry resolves a
    # call_contract callee by module-qualified `contract_id` (always unambiguous)
    # AND by short `name` when that short name is owned by exactly ONE contract.
    # A short name owned by >1 contract (now possible across modules) is recorded
    # as ambiguous ⇒ OOF-DECL-AMBIGUOUS-CONTRACT at the call site.
    def build_call_contract_registry(classified_program)
      contracts   = classified_program.fetch("contracts")
      name_to_ids = Hash.new { |h, k| h[k] = [] }
      contracts.each { |c| name_to_ids[c.fetch("name")] << c.fetch("contract_id") }

      entries   = {}
      ambiguous = {}
      contracts.each do |contract|
        name    = contract.fetch("name")
        cid     = contract.fetch("contract_id")
        decls   = contract.fetch("declarations")
        inputs  = decls.select { |d| d.fetch("kind") == "input" }
        outputs = decls.select { |d| d.fetch("kind") == "output" }
        entry = {
          "modifier"           => contract.fetch("modifier", "pure"),
          "input_count"        => inputs.size,
          "input_names"        => inputs.map { |d| d.fetch("name") },
          "single_output_type" => outputs.size == 1 ? outputs[0].fetch("type_annotation", nil) : nil,
          "single_output_name" => outputs.size == 1 ? outputs[0].fetch("name") : nil,
          "contract_name"      => name,
          "contract_id"        => cid
        }
        # PROP-050 / LAB-EFFECT-CALL-V0-P3 (S1): callee effect-surface fields
        # consumed by `invoke ... using` checks (OOF-EC1/EC2/EC3/EC5) and SIR
        # absorption. ADDITIVE keys only — the call_contract path reads none of
        # these; its purity gate below stays byte-identical.
        cap_decls = decls.select { |d| d.fetch("kind") == "capability" }
        cap_types = cap_decls.to_h { |d| [d.fetch("name"), annotation_type_name(d.fetch("type_annotation", nil))] }
        entry["capabilities"] = cap_decls.map { |d| { "name" => d.fetch("name"), "type" => cap_types[d.fetch("name")] } }
        entry["effects"] = decls.select { |d| d.fetch("kind") == "effect_binding" }.map do |d|
          cap_ref = d.fetch("deps", []).first  # classifier deps = [capability_ref] when declared
          { "name" => d.fetch("name"), "capability_ref" => cap_ref,
            "capability_type" => cap_ref ? cap_types[cap_ref] : nil }
        end
        entry["affects"]          = decls.select { |d| d.fetch("kind") == "affects" }.filter_map { |d| d.fetch("target", nil) }
        entry["idempotency_mode"] = decls.find { |d| d.fetch("kind") == "idempotency" }&.fetch("mode", nil)
        entry["reversibility"]    = decls.find { |d| d.fetch("kind") == "reversibility" }&.fetch("value", nil)
        entry["authority"]        = decls.find { |d| d.fetch("kind") == "authority" }&.fetch("ref", nil)
        entry["receipt_type"]     = annotation_type_name(decls.find { |d| d.fetch("kind") == "receipt" }&.fetch("type_annotation", nil))
        entry["failure_type"]     = annotation_type_name(decls.find { |d| d.fetch("kind") == "failure" }&.fetch("type_annotation", nil))
        entry["has_invoke"]       = decls.any? { |d| d.fetch("kind") == "invoke" }
        entries[cid] = entry                       # qualified id always resolves
        if name_to_ids[name].size == 1
          entries[name] = entry                    # unambiguous short name resolves
        else
          ambiguous[name] = name_to_ids[name].uniq.sort
        end
      end
      { "entries" => entries, "ambiguous" => ambiguous }
    end

    # LAB-RUBY-CALL-CONTRACT-PARITY-P3: infer call_contract(...) call.
    # Tier 1 — literal String callee: registry lookup, purity/arity/self-recursion checks, resolve output type.
    # Tier 2 — non-literal callee: Unknown, no error (VM fail-closed from LAB-RACK-P9).
    def infer_call_contract(expr, symbol_types, type_errors, type_warnings, node_name)
      fn   = expr.fetch("fn")
      args = expr.fetch("args")

      if args.empty?
        type_errors << oof("OOF-TY0",
          "call_contract requires at least one argument (contract name as String)",
          node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => fn, "args" => [])
      end

      typed_name_arg = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      name_arg_type  = type_name(typed_name_arg.fetch("resolved_type"))

      unless name_arg_type == "String" || name_arg_type == "Unknown"
        type_errors << oof("OOF-TY0",
          "call_contract: first argument must be String (contract name), got #{name_arg_type}",
          node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => fn, "args" => [])
      end

      first_raw = args[0]
      if first_raw.fetch("kind", nil) == "literal" && first_raw.fetch("type_tag", nil) == "String"
        callee_name      = first_raw.fetch("value")
        positional_count = args.size - 1

        # LANG-PACKAGE-CONTRACT-IDENTITY-P2: an unqualified short name owned by
        # more than one contract (possible now that two modules may both declare
        # `Render`) is ambiguous — fail closed and require a qualified name.
        if @call_contract_registry.fetch("ambiguous").key?(callee_name)
          cands = @call_contract_registry.fetch("ambiguous").fetch(callee_name)
          type_errors << oof("OOF-DECL-AMBIGUOUS-CONTRACT",
            "call_contract('#{callee_name}') is ambiguous — #{cands.size} contracts declare the " \
            "short name '#{callee_name}' (#{cands.join(', ')}); use a qualified name, " \
            "e.g. call_contract('#{cands.first}')",
            node_name)
          return typed_expr("call", type_ir("Unknown"), [], "fn" => fn, "args" => [])
        end

        entry = @call_contract_registry.fetch("entries")[callee_name]

        if entry.nil?
          type_errors << oof("OOF-TY0",
            "call_contract: unknown callee '#{callee_name}' — not found in this module",
            node_name)
          return typed_expr("call", type_ir("Unknown"), [], "fn" => fn, "args" => [])
        end

        if entry["modifier"] != "pure"
          type_errors << oof("OOF-TY0",
            "call_contract: callee '#{callee_name}' is not pure (modifier: #{entry["modifier"]}); only pure contracts may be called via call_contract in v0",
            node_name)
          return typed_expr("call", type_ir("Unknown"), [], "fn" => fn, "args" => [])
        end

        if callee_name == @current_contract_name
          type_errors << oof("OOF-TY0",
            "call_contract: self-recursion via '#{callee_name}' is closed in v0; use recur() for recursive contracts",
            node_name)
          return typed_expr("call", type_ir("Unknown"), [], "fn" => fn, "args" => [])
        end

        if positional_count != entry["input_count"]
          type_errors << oof("OOF-TY0",
            "call_contract: callee '#{callee_name}' expects #{entry["input_count"]} input(s), got #{positional_count}",
            node_name)
          return typed_expr("call", type_ir("Unknown"), [], "fn" => fn, "args" => [])
        end

        # All checks pass — resolve output type.
        # LANG-OUTPUT-TYPE-ASSIGNABILITY-P3 is implemented; structurally_assignable?
        # covers parametric types at the output boundary so we resolve fully here.
        out_type = entry["single_output_type"] ? type_ir(entry["single_output_type"]) : type_ir("Unknown")
        typed_positional = args[1..].map { |a| infer_expr(a, symbol_types, type_errors, type_warnings, node_name) }
        all_deps = typed_name_arg.fetch("deps", []) + typed_positional.flat_map { |a| a.fetch("deps", []) }
        typed_expr("call", out_type, all_deps, "fn" => fn, "args" => [typed_name_arg] + typed_positional)
      else
        # Tier 2 — dynamic / variable callee: Unknown, no error.
        typed_expr("call", type_ir("Unknown"), typed_name_arg.fetch("deps", []), "fn" => fn, "args" => [typed_name_arg])
      end
    end

    # PROP-050 (ratified) / LAB-EFFECT-CALL-V0-P3 (S1): typecheck
    #   invoke <binding> = contract("Callee", args...) using caps
    # Reuses the call_contract registry (@call_contract_registry) for callee
    # resolution — the call_contract purity gate itself is UNTOUCHED (invoke is
    # the designed non-pure call; call_contract stays pure-only permanently).
    # Rules (OOF-EC namespace, PROP-050 D2; all fail-closed):
    #   OOF-EC1 — callee unknown; `pure` callee (use call_contract); recursive/
    #             service/convergent/fuel_bounded callee (held in v0);
    #             self-invocation (closed by the existing call-cycle rules)
    #   OOF-EC2 — surface absorption: every callee effect (verb + capability
    #             TYPE) and every callee affects target must be covered by a
    #             caller declaration (caller's effective surface = own U invoked)
    #   OOF-EC3 — attenuation: every callee capability slot matched by exactly
    #             one `using` name of the same capability TYPE; a `using` name
    #             matching no slot is an over-grant; every `using` name must be
    #             a declared caller capability
    #   OOF-EC4 — escalation matrix, caller side (pure caller already fired in
    #             the Classifier): observed -> observed only; effect/privileged/
    #             irreversible -> observed|effect; other caller classes refused
    #   OOF-EC5 — depth-1: a callee that itself contains an invoke is refused
    # Arity mismatch mirrors call_contract (OOF-TY0). Result binding takes the
    # callee's single output type (multi-output => Unknown, the call_contract v0
    # rule); the binding is an ordinary local (later computes, §13.6 evidence).
    # Declaration != execution: a passing invoke grants no runtime authority.
    def typecheck_invoke(decl, caller_modifier, all_decls, symbol_types, type_errors, type_warnings)
      binding     = decl.fetch("binding", decl.fetch("name"))
      callee_name = decl.fetch("callee", nil)
      using_names = decl.fetch("using", [])
      args        = decl.fetch("args", [])

      # Invoke ARG exprs go through normal inference from day one — an
      # unresolved ref fails closed with OOF-P1 exactly like a compute expr.
      typed_args = args.map { |a| infer_expr(a, symbol_types, type_errors, type_warnings, binding) }

      out_type     = type_ir("Unknown")
      absorbed     = nil
      effects_flat = []

      if @call_contract_registry.fetch("ambiguous").key?(callee_name)
        cands = @call_contract_registry.fetch("ambiguous").fetch(callee_name)
        type_errors << oof("OOF-DECL-AMBIGUOUS-CONTRACT",
          "invoke contract('#{callee_name}') is ambiguous — #{cands.size} contracts declare the " \
          "short name '#{callee_name}' (#{cands.join(', ')}); use a qualified name",
          binding)
      elsif (entry = @call_contract_registry.fetch("entries")[callee_name]).nil?
        type_errors << oof("OOF-EC1",
          "invoke: unknown callee '#{callee_name}' — not found in this compilation unit",
          binding)
      elsif entry["contract_name"] == @current_contract_name
        type_errors << oof("OOF-EC1",
          "invoke: self-invocation via '#{callee_name}' is closed (existing call-cycle rules, PROP-050)",
          binding)
      elsif entry["modifier"] == "pure"
        type_errors << oof("OOF-EC1",
          "invoke: callee '#{callee_name}' is pure — use call_contract for pure contracts",
          binding)
      elsif !%w[observed effect privileged irreversible].include?(entry["modifier"])
        type_errors << oof("OOF-EC1",
          "invoke of a '#{entry["modifier"]}' contract ('#{callee_name}') is held in v0 (PROP-050)",
          binding)
      else
        callee_mod = entry["modifier"]

        # OOF-EC4 escalation matrix (caller side). The pure-caller arm fired in
        # the Classifier (post-loop gate); caller classes outside the ratified
        # matrix (recursive/service/convergent/fuel_bounded) are refused —
        # fail-closed, D4 full compile-side matrix.
        allowed = case caller_modifier
                  when "pure"                                 then nil # Classifier owns this arm
                  when "observed"                             then %w[observed]
                  when "effect", "privileged", "irreversible" then %w[observed effect]
                  else []
                  end
        if allowed && !allowed.include?(callee_mod)
          type_errors << oof("OOF-EC4",
            "#{caller_modifier} contract '#{@current_contract_name}' may not invoke #{callee_mod} " \
            "contract '#{callee_name}' (escalation matrix: observed->observed; " \
            "effect/privileged/irreversible->observed|effect)",
            binding)
        end

        # OOF-EC5 — depth-1: the callee itself contains an invoke.
        if entry["has_invoke"]
          type_errors << oof("OOF-EC5",
            "invoke: callee '#{callee_name}' itself contains an invoke — depth-1 only in v0 (PROP-050)",
            binding)
        end

        # Arity mirrors the call_contract check (same machinery, same code).
        if args.size != entry["input_count"]
          type_errors << oof("OOF-TY0",
            "invoke: callee '#{callee_name}' expects #{entry["input_count"]} input(s), got #{args.size}",
            binding)
        end

        # Caller-side declared surface (classified declarations of THIS contract).
        caller_caps    = {}  # capability name => declared type name
        caller_effects = []  # { "name", "capability_ref" }
        caller_affects = []
        all_decls.each do |d|
          case d.fetch("kind", "")
          when "capability"
            caller_caps[d.fetch("name")] = annotation_type_name(d.fetch("type_annotation", nil))
          when "effect_binding"
            caller_effects << { "name" => d.fetch("name"), "capability_ref" => d.fetch("deps", []).first }
          when "affects"
            caller_affects << d.fetch("target", nil)
          end
        end

        # OOF-EC2 — surface absorption, fail-closed PER missing item: each callee
        # effect needs a caller effect of the same verb whose capability has the
        # same declared TYPE; each callee affects target must appear in caller affects.
        entry.fetch("effects", []).each do |ce|
          covered = caller_effects.any? do |ee|
            ee["name"] == ce["name"] && ee["capability_ref"] &&
              caller_caps[ee["capability_ref"]] == ce["capability_type"]
          end
          next if covered
          type_errors << oof("OOF-EC2",
            "invoke '#{callee_name}': callee effect '#{ce["name"]}' (capability type " \
            "#{ce["capability_type"] || "Unknown"}) is not covered by a caller effect declaration",
            binding)
        end
        entry.fetch("affects", []).each do |target|
          next if caller_affects.include?(target)
          type_errors << oof("OOF-EC2",
            "invoke '#{callee_name}': callee affects target '#{target}' is not declared " \
            "in the caller's affects",
            binding)
        end

        # OOF-EC3 — attenuation mapping between `using` names and callee slots.
        resolved = []
        using_names.each do |u|
          if caller_caps.key?(u)
            resolved << u
          else
            type_errors << oof("OOF-EC3",
              "invoke '#{callee_name}': using '#{u}' is not a declared caller capability",
              binding)
          end
        end
        available = resolved.dup
        slot_map  = {}  # callee slot name => matched caller `using` name
        entry.fetch("capabilities", []).each do |slot|
          idx = available.index { |u| caller_caps[u] == slot["type"] }
          if idx
            slot_map[slot["name"]] = available.delete_at(idx)
          else
            type_errors << oof("OOF-EC3",
              "invoke '#{callee_name}': callee capability slot '#{slot["name"]}: #{slot["type"]}' " \
              "has no matching 'using' capability of that type",
              binding)
          end
        end
        available.each do |extra|
          type_errors << oof("OOF-EC3",
            "invoke '#{callee_name}': using '#{extra}' matches no callee capability slot " \
            "(over-granting is refused)",
            binding)
        end

        # Result binding: callee's single output type (call_contract v0 rule).
        out_type = entry["single_output_type"] ? type_ir(entry["single_output_type"]) : type_ir("Unknown")

        # SIR absorption record (packet §5) — carried on the typed decl for the
        # emitter; absent callee fields stay null.
        absorbed = {
          "effects"          => entry.fetch("effects", []).map { |ce| { "name" => ce["name"], "capability_type" => ce["capability_type"] } },
          "affects"          => entry.fetch("affects", []),
          "idempotency_mode" => entry["idempotency_mode"],
          "reversibility"    => entry["reversibility"],
          "receipt_type"     => entry["receipt_type"],
          "failure_type"     => entry["failure_type"],
          "authority"        => entry["authority"]
        }
        # Flattened caller-namespace effect entries with via_invoke provenance:
        # capability_ref speaks the CALLER's vocabulary (the matched `using` name).
        effects_flat = entry.fetch("effects", []).map do |ce|
          { "name"           => ce["name"],
            "capability_ref" => ce["capability_ref"] ? slot_map[ce["capability_ref"]] : nil,
            "via_invoke"     => entry["contract_name"] }
        end
      end

      symbol_types[binding] = out_type
      td = typed_decl(decl, out_type, nil, [])
             .merge("binding" => binding, "callee" => callee_name,
                    "using" => using_names, "args" => typed_args)
      td["absorbed"]     = absorbed if absorbed
      td["effects_flat"] = effects_flat unless effects_flat.empty?
      td
    end

    # LANG-TYPED-CONTRACT-REF-PROP-P3: resolve a uses_contract declaration.
    def typecheck_uses_contract(decl, current_contract_name, type_errors)
      target = decl.fetch("target")

      if target == current_contract_name
        type_errors << oof(
          "OOF-REF4",
          "contract '#{current_contract_name}' uses itself — self-reference is not allowed",
          "uses_contract:#{target}"
        )
        return typed_decl(decl, type_ir("ContractRef"), nil, []).merge(
          "target" => target, "resolution_status" => "unresolved"
        )
      end

      # PATH 1 — Qualified cross-module reference (dotted target)
      if target.include?(".")
        dot_idx = target.rindex(".")
        mod_path = target[0, dot_idx]
        contract_name = target[(dot_idx + 1)..]
        mod_registry = @cross_module_registry[mod_path]
        unless mod_registry
          type_errors << oof(
            "OOF-REF1",
            "contract '#{current_contract_name}' uses '#{target}' — " \
            "module '#{mod_path}' is not in the compilation unit",
            "uses_contract:#{target}"
          )
          return typed_decl(decl, type_ir("ContractRef"), nil, []).merge(
            "target" => target, "resolution_status" => "unresolved", "resolution_kind" => "unresolved"
          )
        end
        entry = mod_registry[contract_name]
        unless entry
          type_errors << oof(
            "OOF-REF1",
            "contract '#{current_contract_name}' uses '#{target}' — " \
            "module '#{mod_path}' does not declare contract '#{contract_name}'",
            "uses_contract:#{target}"
          )
          return typed_decl(decl, type_ir("ContractRef"), nil, []).merge(
            "target" => target, "resolution_status" => "unresolved", "resolution_kind" => "unresolved"
          )
        end
        return typed_decl(decl, type_ir("ContractRef"), nil, []).merge(
          "target"            => target,
          "resolution_status" => "resolved",
          "resolution_kind"   => "qualified",
          "resolved_ref"      => {
            "contract_name" => contract_name,
            "module_name"   => mod_path,
            "modifier"      => entry.fetch("modifier"),
            "input_count"   => entry.fetch("input_count"),
            "input_names"   => entry.fetch("input_names"),
            "input_types"   => entry.fetch("input_types", []),
            "output_names"  => entry.fetch("output_names"),
            "output_types"  => entry.fetch("output_types", []),
            "single_output_type" => entry.fetch("single_output_type", nil)
          }
        )
      end

      # PATH 2a — Unqualified: same-module (local shadows imported)
      # In multifile mode, per_contract_module tells us each contract's original module.
      # A contract is "local" only if it comes from the same original module as the declaring contract.
      declaring_module = @per_contract_module.fetch(current_contract_name, @classified_module)
      entry = @same_module_registry[target]
      if entry
        target_module = @per_contract_module.fetch(target, nil)
        if target_module.nil? || target_module == declaring_module
          # Truly same-module: nil means single-file (per_contract_module empty), or explicit match
          effective_module = target_module || @classified_module
          return typed_decl(decl, type_ir("ContractRef"), nil, []).merge(
            "target"            => target,
            "resolution_status" => "resolved",
            "resolution_kind"   => "local",
            "resolved_ref"      => {
              "contract_name" => target,
              "module_name"   => effective_module,
              "modifier"      => entry.fetch("modifier"),
              "input_count"   => entry.fetch("input_count"),
              "input_names"   => entry.fetch("input_names"),
              "input_types"   => entry.fetch("input_types", []),
              "output_names"  => entry.fetch("output_names"),
              "output_types"  => entry.fetch("output_types", []),
              "single_output_type" => entry.fetch("single_output_type", nil)
            }
          )
        end
        # Target is from a different original module but merged — fall through to PATH 2b
      end

      # PATH 2b — Unqualified: scan imported modules
      import_scope = resolve_import_scope_for(declaring_module)
      candidates = []
      import_scope.each do |imp_mod, visibility|
        next unless @cross_module_registry.key?(imp_mod)
        mod_registry = @cross_module_registry[imp_mod]
        next unless mod_registry.key?(target)
        if visibility == :all || visibility.include?(target)
          candidates << { "module_name" => imp_mod, "entry" => mod_registry[target] }
        end
      end

      case candidates.size
      when 0
        type_errors << oof(
          "OOF-REF1",
          "contract '#{current_contract_name}' uses unknown contract '#{target}' — " \
          "no contract named '#{target}' is declared in this module or any imported module",
          "uses_contract:#{target}"
        )
        typed_decl(decl, type_ir("ContractRef"), nil, []).merge(
          "target" => target, "resolution_status" => "unresolved", "resolution_kind" => "unresolved"
        )
      when 1
        mod_path = candidates[0]["module_name"]
        entry    = candidates[0]["entry"]
        typed_decl(decl, type_ir("ContractRef"), nil, []).merge(
          "target"            => target,
          "resolution_status" => "resolved",
          "resolution_kind"   => "imported",
          "resolved_ref"      => {
            "contract_name" => target,
            "module_name"   => mod_path,
            "modifier"      => entry.fetch("modifier"),
            "input_count"   => entry.fetch("input_count"),
            "input_names"   => entry.fetch("input_names"),
            "input_types"   => entry.fetch("input_types", []),
            "output_names"  => entry.fetch("output_names"),
            "output_types"  => entry.fetch("output_types", []),
            "single_output_type" => entry.fetch("single_output_type", nil)
          }
        )
      else
        mod_names = candidates.map { |c| c["module_name"] }
        type_errors << oof(
          "OOF-REF2",
          "contract '#{current_contract_name}' uses '#{target}' — ambiguous: contract '#{target}' " \
          "is exported by multiple imported modules: #{mod_names.join(", ")}; " \
          "qualify the reference, e.g. uses #{mod_names[0]}.#{target}",
          "uses_contract:#{target}"
        )
        typed_decl(decl, type_ir("ContractRef"), nil, []).merge(
          "target" => target, "resolution_status" => "unresolved", "resolution_kind" => "unresolved"
        )
      end
    end

    def register_current_contract_ref(typed_ref)
      return unless typed_ref.fetch("resolution_status", nil) == "resolved"

      resolved = typed_ref.fetch("resolved_ref")
      @current_contract_refs[typed_ref.fetch("target")] = resolved
      @current_contract_refs[resolved.fetch("contract_name")] ||= resolved
    end

    # LANG-TYPED-CONTRACT-REF-PROP-P5: import scope for a given module.
    # Returns { module_path => :all | Set<contract_name> }.
    def resolve_import_scope_for(module_name)
      imports = @per_module_imports.fetch(module_name, [])
      imports.each_with_object({}) do |import, scope|
        mod_path = import.fetch("module_path", nil)
        next unless mod_path
        names = import.fetch("names", nil)
        scope[mod_path] = names ? names.to_set : :all
      end
    end

    # LANG-TYPED-CONTRACT-REF-PROP-P5: detect same-module or merged-unit uses-cycles.
    # Runs a DFS over the resolved dependency graph after all contracts are typed.
    def detect_uses_cycles(typed_contracts)
      graph = {}
      typed_contracts.each do |contract|
        name = contract.fetch("name")
        targets = contract.fetch("contract_ref_declarations", [])
          .select { |r| r.fetch("resolution_status", "unresolved") == "resolved" }
          .map { |r| r.dig("resolved_ref", "contract_name") }
          .compact
        graph[name] = targets
      end

      color = graph.keys.each_with_object({}) { |n, h| h[n] = :white }
      reported = {}
      errors = []

      graph.each_key do |start|
        next unless color[start] == :white
        dfs_visit(start, graph, color, [], errors, reported)
      end

      errors
    end

    def dfs_visit(node, graph, color, path, errors, reported)
      return unless color[node] == :white
      color[node] = :gray
      current_path = path + [node]

      (graph[node] || []).each do |neighbor|
        next unless graph.key?(neighbor)
        if color[neighbor] == :gray
          idx   = current_path.index(neighbor) || 0
          cycle = current_path[idx..] + [neighbor]
          key   = cycle.sort.join(",")
          unless reported.key?(key)
            reported[key] = true
            errors << oof(
              "OOF-REF4",
              "typed-ref cycle detected: #{cycle.join(" → ")} — " \
              "contracts cannot form circular uses-dependency chains",
              "uses_contract:cycle"
            )
          end
        elsif color[neighbor] == :white
          dfs_visit(neighbor, graph, color, current_path, errors, reported)
        end
      end

      color[node] = :black
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
        # PROP-041 T2: suppress OOF-P1 for stdlib-certified and user-registered structural accessors
        field = expr.fetch("field", "")
        obj_node = expr.fetch("object", {})
        if obj_node.is_a?(Hash) && obj_node.fetch("kind", "") == "ref"
          obj_name    = obj_node.fetch("name", "")
          obj_type_ir = symbol_types.fetch(obj_name, nil)
          if obj_type_ir
            obj_type = type_name(obj_type_ir)
            # Collection.tail / Collection.rest — stdlib_certified; no OOF-P1
            if obj_type == "Collection" && %w[tail rest].include?(field)
              obj_typed = typed_expr("ref", obj_type_ir, [obj_name], "name" => obj_name)
              return typed_expr("field_access", obj_type_ir, [obj_name],
                               "object" => obj_typed, "field" => field)
            end
            # T2 registered accessor — suppress OOF-P1 for the subject's accessor
            if @t2_context&.fetch(:kind) == :t2_pass &&
               obj_name == @t2_context[:subject] &&
               field    == @t2_context[:accessor]
              obj_typed = typed_expr("ref", obj_type_ir, [obj_name], "name" => obj_name)
              return typed_expr("field_access", obj_type_ir, [obj_name],
                               "object" => obj_typed, "field" => field)
            end
            # PROP-042 T3: suppress OOF-P1 for any field access on the T3-measured input.
            # Structural coverage is checked in t3_call_site_check; OOF-R11 is authoritative.
            if @t3_context&.fetch(:kind) == :t3_pass && obj_name == @t3_context[:arg_name]
              obj_typed = typed_expr("ref", obj_type_ir, [obj_name], "name" => obj_name)
              return typed_expr("field_access", obj_type_ir, [obj_name],
                               "object" => obj_typed, "field" => field)
            end
          end
        end
        object = infer_expr(expr.fetch("object"), symbol_types, type_errors, type_warnings, node_name)
        object_type = type_name(object.fetch("resolved_type"))
        # LANG-STDLIB-COLLECTION-ZIP-RUBY-PARITY-P3: built-in Pair{first, second} — the element
        # type `zip` produces. Fields resolve from the type params ([A, B]); a missing/empty param
        # stays Unknown WITHOUT OOF-P1 (permissive, mirroring the Rust Pair field-access fix from
        # LAB-STDLIB-COLLECTION-ZIP-PROOF-P2).
        if object_type == "Pair" && %w[first second].include?(expr.fetch("field"))
          pair_params = object.fetch("resolved_type", {}).fetch("params", [])
          pair_field = pair_params[expr.fetch("field") == "first" ? 0 : 1]
          pair_field = type_ir("Unknown") unless pair_field.is_a?(Hash) && !pair_field.empty?
          return typed_expr("field_access", pair_field, object.fetch("deps"),
                            "object" => object, "field" => expr.fetch("field"))
        end
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
      when "form_invocation"
        infer_form_invocation(expr, symbol_types, type_errors, type_warnings, node_name)
      when "index_access"
        infer_index_access(expr, symbol_types, type_errors, type_warnings, node_name)
      when "if_expr"
        infer_if_expr(expr, symbol_types, type_errors, type_warnings, node_name)
      when "array_literal"  # PROP-043: Collection[T] inference for map_from_pairs inputs
        infer_array_literal(expr, symbol_types, type_errors, type_warnings, node_name)
      when "record_literal"  # PROP-043: named Record inference via @output_type_hints
        infer_record_literal(expr, symbol_types, type_errors, type_warnings, node_name)
      when "variant_construct"  # PROP-044 P5
        infer_variant_construct(expr, symbol_types, type_errors, type_warnings, node_name)
      when "match_expr"         # PROP-044 P5
        infer_match_expr(expr, symbol_types, type_errors, type_warnings, node_name)
      when "unary_op"
        infer_unary_op(expr, symbol_types, type_errors, type_warnings, node_name)
      else
        type_errors << oof("OOF-TY0", "Unsupported expression kind: #{expr.fetch("kind")}", node_name)
        typed_expr("unsupported", type_ir("Unknown"), [], "source_kind" => expr.fetch("kind"))
      end
    end

    def infer_form_invocation(expr, symbol_types, type_errors, type_warnings, node_name)
      trigger = expr.fetch("trigger")
      resolved = @current_contract_refs.fetch(trigger, nil)
      unless resolved
        type_errors << oof(
          "OOF-FORM1",
          "form invocation '#{trigger}' requires an explicit uses declaration for the target contract",
          node_name
        )
        return typed_expr("form_invocation", type_ir("Unknown"), [], "trigger" => trigger)
      end

      unless resolved.fetch("modifier", "pure") == "pure"
        type_errors << oof(
          "OOF-FORM2",
          "form invocation '#{trigger}' targets #{resolved.fetch("modifier")} contract '#{resolved.fetch("contract_name")}'; only pure targets are allowed",
          node_name
        )
      end

      input_names = resolved.fetch("input_names", [])
      input_types = resolved.fetch("input_types", [])
      attrs = expr.fetch("attrs", [])
      attr_map = {}
      attrs.each do |attr|
        name = attr.fetch("name")
        if attr_map.key?(name)
          type_errors << oof("OOF-FORM3", "duplicate form attribute '#{name}'", node_name)
        end
        attr_map[name] = attr.fetch("value")
      end

      extras = attr_map.keys - input_names
      extras.each do |name|
        type_errors << oof(
          "OOF-FORM4",
          "form invocation '#{trigger}' has unknown attribute '#{name}'",
          node_name
        )
      end

      children = expr.fetch("children", [])
      if children.any? && !input_names.include?("children")
        type_errors << oof(
          "OOF-FORM5",
          "form invocation '#{trigger}' has children but target contract has no 'children' input",
          node_name
        )
      end

      typed_args = []
      input_names.each_with_index do |input_name, idx|
        expected = input_types[idx] ? type_ir(input_types[idx]) : type_ir("Unknown")
        raw_arg = if input_name == "children"
          { "kind" => "array_literal", "items" => children }
        elsif attr_map.key?(input_name)
          attr_map.fetch(input_name)
        else
          type_errors << oof(
            "OOF-FORM6",
            "form invocation '#{trigger}' missing required attribute '#{input_name}'",
            node_name
          )
          { "kind" => "literal", "value" => nil, "type_tag" => "Nil" }
        end

        typed_arg = infer_expr(raw_arg, symbol_types, type_errors, type_warnings, node_name)
        actual = typed_arg.fetch("resolved_type")
        unless unknown_or_unknown_bearing?(actual) || unknown_or_unknown_bearing?(expected) ||
               structurally_assignable?(actual, expected)
          type_errors << oof(
            "OOF-FORM7",
            "form invocation '#{trigger}' input '#{input_name}' expected #{type_display(expected)}, got #{type_display(actual)}",
            node_name
          )
        end
        typed_args << {
          "name" => input_name,
          "expected_type" => expected,
          "expr" => typed_arg
        }
      end

      out_type = resolved.fetch("single_output_type", nil) ? type_ir(resolved.fetch("single_output_type")) : type_ir("Unknown")
      if resolved.fetch("output_names", []).length != 1
        type_errors << oof(
          "OOF-FORM8",
          "form invocation '#{trigger}' target must have exactly one output",
          node_name
        )
      end

      typed_expr(
        "form_invocation",
        out_type,
        typed_args.flat_map { |arg| arg.fetch("expr").fetch("deps", []) }.uniq,
        "trigger" => trigger,
        "resolved_ref" => resolved,
        "args" => typed_args
      )
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
      when "recur"
        infer_recur_call(expr, symbol_types, type_errors, type_warnings, node_name)
      when "concat"
        # LANG-STDLIB-COLLECTION-CONCAT-PROP-P3: shared source alias — route by first-arg type
        infer_concat_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when "zip"
        # LANG-STDLIB-COLLECTION-ZIP-RUBY-PARITY-P3: zip(Collection[A], Collection[B]) ->
        # Collection[Pair[A, B]] — canon registration of the surface already live on the lab
        # Rust compiler + VM ({first, second} records, truncate-to-min).
        infer_zip_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when *TEXT_STDLIB_FNS.keys
        # igniter-string-core-units-and-pure-stdlib-boundary-v0
        infer_text_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when *NUMERIC_STDLIB_ALIASES.keys
        # LANG-STDLIB-NUMERIC-TEXT-CONVERSION-P1: parse_int / int_to_text / modulo (bare +
        # stdlib.numeric.* + stdlib.integer.* aliases resolve to the canonical stdlib.integer.* SIR name)
        infer_numeric_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when *MAP_STDLIB_FNS.keys
        # PROP-043: Map[String,V] stdlib — map_get/map_has_key/map_from_pairs/map_empty
        infer_map_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when *OUTCOME_STDLIB_FNS.keys
        # LANG-STDLIB-OUTCOME-PROP-P3: stdlib.outcome helpers — kind + 6 PROP-047 predicates
        infer_outcome_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when "filter_map"
        # LANG-SUMTYPE-COLLECT-P3: filter_map(Collection[T], T -> Option[U]) -> Collection[U]
        infer_filter_map_call(args, symbol_types, type_errors, type_warnings, node_name)
      when *COLLECTION_HOF_FNS.keys
        # LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P1: Collection HOF — map/filter/count
        infer_collection_hof_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when *COLLECTION_FIRST_LAST_FNS.keys
        # LANG-STDLIB-COLLECTION-FIRST-LAST-P2: first/last -> Option[T], Rust-parity fallback Option[Unknown].
        infer_collection_first_last_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when "sum"
        # LANG-STDLIB-SUM-PROP-P3: stdlib.collection.sum two-arg field-projection form
        infer_sum_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when "fold"
        # LANG-STDLIB-FOLD-PROP-P1/P3: stdlib.collection.fold — accumulator HOF
        infer_fold_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when "append"
        # LANG-STDLIB-COLLECTION-APPEND-PROP-P3: stdlib.collection.append
        infer_append_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when "is_empty", "non_empty"
        # LANG-STDLIB-IS-EMPTY-PROP-P3: stdlib.collection.is_empty + stdlib.collection.non_empty
        infer_is_empty_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when "char_at"
        # LANG-STDLIB-STRING-SURFACE-P3: char_at(String, Integer) -> String
        infer_char_at_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when "substring"
        # LANG-STDLIB-STRING-SUBSTRING-P2: substring(String, Integer, Integer) -> String
        infer_substring_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when "range"
        # LANG-STDLIB-COLLECTION-RANGE-P2: range(start, stop) -> Collection[Integer]
        infer_range_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when "decimal"
        # LAB-NUMERIC-DECIMAL-CONSTRUCT-P1: decimal(value, scale) -> Decimal[scale]
        infer_decimal_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when "or_else"
        # PROP-043: Option[V] unwrap with default (or_else introduced alongside Map v0)
        infer_or_else(args, symbol_types, type_errors, type_warnings, node_name)
      when *SEALED_CONSTRUCTORS
        # LANG-SUMTYPE-CONSTRUCT-MATCH-P3: sealed built-in constructors some/none/ok/err
        infer_sealed_construct(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when "unwrap_or"
        # LANG-SUMTYPE-CONSTRUCT-MATCH-P3: unwrap_or(Result[T,E]|Option[T], default) -> T
        infer_unwrap_or(args, symbol_types, type_errors, type_warnings, node_name)
      when "and_then"
        # LANG-SUMTYPE-CONSTRUCT-MATCH-P3: and_then(Result[T,E], (T -> Result[U,E])) -> Result[U,E]
        infer_and_then(args, symbol_types, type_errors, type_warnings, node_name)
      when "call_contract"
        # LAB-RUBY-CALL-CONTRACT-PARITY-P3: Tier 1 literal same-module + Tier 2 dynamic
        infer_call_contract(expr, symbol_types, type_errors, type_warnings, node_name)
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

    # LANG-RUBY-NUMERIC-OPS-PARITY-P1: scale of a Decimal type. The scale param may be a
    # bare scalar (e.g. the integer 2 from a `Decimal[2]` annotation) or a named type node
    # (`{"name"=>"2"}` from the `decimal()` constructor); both normalise to a string.
    def decimal_scale(t)
      p = t.fetch("params", []).first
      return "0" if p.nil?
      (p.is_a?(Hash) ? p.fetch("name", "0") : p).to_s
    end

    def operator_type(op, left, right, type_errors, node_name)
      left_name = type_name(left)
      right_name = type_name(right)

      # LANG-RUBY-NUMERIC-OPS-PARITY-P1: mirror the Rust homogeneous numeric relaxation.
      # (a) Fixed-point Decimal rules — both operands Decimal:
      #     +/- require equal scale (OOF-TC5) and return Decimal[scale]; * -> Decimal[A+B].
      if left_name == "Decimal" && right_name == "Decimal"
        left_scale  = decimal_scale(left)
        right_scale = decimal_scale(right)
        case op
        when "+", "-"
          unless left_scale == right_scale
            type_errors << oof("OOF-TC5",
              "Decimal scale mismatch in operator '#{op}': left_scale=#{left_scale}, right_scale=#{right_scale}",
              node_name)
          end
          return ["stdlib.decimal.add", left.dup]
        when "*"
          sum_scale = left_scale.to_i + right_scale.to_i
          return ["stdlib.decimal.mul", { "name" => "Decimal", "params" => [{ "name" => sum_scale.to_s, "params" => [] }] }]
        end
      end

      # (b) v0 homogeneous numeric relaxation: both sides the SAME numeric family
      #     (Integer/Float/Decimal). Arithmetic returns the operand type; comparison and
      #     == return Bool. The VM binary opcodes already dispatch on value type, so the
      #     nominal stdlib.integer.* fn name is fine. Heterogeneous numeric (e.g. Integer
      #     + Float) and Decimal scale mismatch stay rejected by the fall-through below.
      #     Decimal +/-/* are handled in (a); this covers Float (all ops), Decimal (/ and
      #     comparisons and ==), and Integer.
      if left_name == right_name && %w[Integer Float Decimal].include?(left_name)
        case op
        when "+"  then return ["stdlib.integer.add", left.dup]
        when "-"  then return ["stdlib.integer.sub", left.dup]
        when "*"  then return ["stdlib.integer.mul", left.dup]
        when "/"  then return ["stdlib.integer.div", left.dup]
        when "<"  then return ["stdlib.integer.lt",  type_ir("Bool")]
        when "<=" then return ["stdlib.integer.lte", type_ir("Bool")]
        when ">"  then return ["stdlib.integer.gt",  type_ir("Bool")]
        when ">=" then return ["stdlib.integer.gte", type_ir("Bool")]
        when "==" then return ["stdlib.primitive.eq", type_ir("Bool")]
        end
      end

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
      when "<"
        type_errors << type_mismatch(type_ir("Integer"), type_ir("#{left_name}<#{right_name}"), node_name) unless unknown?(left, right) || left_name == "Integer" && right_name == "Integer"
        ["stdlib.integer.lt", type_ir("Bool")]
      when "<="
        type_errors << type_mismatch(type_ir("Integer"), type_ir("#{left_name}<=#{right_name}"), node_name) unless unknown?(left, right) || left_name == "Integer" && right_name == "Integer"
        ["stdlib.integer.lte", type_ir("Bool")]
      when ">="
        type_errors << type_mismatch(type_ir("Integer"), type_ir("#{left_name}>=#{right_name}"), node_name) unless unknown?(left, right) || left_name == "Integer" && right_name == "Integer"
        ["stdlib.integer.gte", type_ir("Bool")]
      when "&&"
        type_errors << type_mismatch(type_ir("Bool"), type_ir("#{left_name}+#{right_name}"), node_name) unless unknown?(left, right) || left_name == "Bool" && right_name == "Bool"
        ["stdlib.bool.and", type_ir("Bool")]
      when "=="
        compatible = unknown?(left, right) ||
                     %w[Text String].include?(left_name) && %w[Text String].include?(right_name) ||
                     left_name == right_name && %w[Integer Bool].include?(left_name)
        type_errors << oof("OOF-TY0", "Type mismatch for ==: cannot compare #{left_name} with #{right_name}", node_name) unless compatible
        ["stdlib.primitive.eq", type_ir("Bool")]
      else
        type_errors << oof("OOF-TY0", "Unsupported operator: #{op}", node_name)
        ["stdlib.unsupported.#{op}", type_ir("Unknown")]
      end
    end

    def typed_expr(kind, type, deps, extra)
      { "kind" => kind }.merge(extra).merge("resolved_type" => type, "deps" => deps.uniq)
    end

    # PROP-050: bare type-name string of a source type annotation (nil-safe).
    # Used for capability-TYPE equality (OOF-EC2/EC3) and absorbed metadata —
    # comparisons run on DECLARED names, fail-closed on any mismatch.
    def annotation_type_name(annotation)
      return nil if annotation.nil?
      annotation.is_a?(Hash) ? annotation.fetch("name", "Unknown") : annotation.to_s
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

    def unknown_or_unknown_bearing?(t)
      return true if type_name(t) == "Unknown"
      # LAB-NUMERIC-DECIMAL-CONSTRUCT-P1: normalise each param through type_ir before
      # recursing — Decimal[N] params arrive as bare scalars (e.g. the integer 2), not
      # type hashes. Mirrors the Rust TC (`self.type_ir(p)`); without it type_name(2)
      # raises NoMethodError. A scale scalar normalises to {"name"=>"2"} (not Unknown).
      t.fetch("params", []).any? { |p| unknown_or_unknown_bearing?(type_ir(p)) }
    end

    def type_mismatch(expected, actual, node)
      oof("OOF-TY0", "Type mismatch: expected #{type_name(expected)}, got #{type_name(actual)}", node)
    end

    def structurally_assignable?(actual, expected)
      return true  if type_name(expected) == "Unknown"
      return false if type_name(actual)   == "Unknown"
      return false if type_name(actual)   != type_name(expected)
      actual_params   = actual.fetch("params",   [])
      expected_params = expected.fetch("params", [])
      return false if actual_params.length != expected_params.length
      # LAB-NUMERIC-DECIMAL-CONSTRUCT-P1: normalise each param through type_ir before
      # recursing. Decimal[N] params arrive as bare scalars (the integer 2), not type
      # hashes; type_ir wraps 2 -> {"name"=>"2"} so scale compares by value (Decimal[2]
      # != Decimal[4]) and type_name no longer raises on a bare Integer. Mirrors Rust.
      actual_params.zip(expected_params).all? { |a, e| structurally_assignable?(type_ir(a), type_ir(e)) }
    end

    # True when `actual` is a parameterised Collection whose params are all Unknown —
    # the "empty array literal" shape — and `expected` is a Collection of the same arity.
    # Used only inside record literal structural candidate matching so that [] is accepted
    # as a field-local wildcard. The output boundary continues to use the strict
    # structurally_assignable? policy and is unaffected by this helper.
    def empty_collection_assignable?(actual, expected)
      return false unless type_name(actual) == "Collection" && type_name(expected) == "Collection"
      ap = actual.fetch("params",   [])
      ep = expected.fetch("params", [])
      return false unless ap.length == ep.length && !ap.empty?
      ap.all? { |p| type_name(p) == "Unknown" }
    end

    def structural_mismatch(expected, actual, node)
      oof("OOF-TY1",
          "Output type mismatch: expected #{type_display(expected)}, got #{type_display(actual)}",
          node)
    end

    def record_literal_field_node_name(node_name, field_name)
      node_name ? "#{node_name}.#{field_name}" : field_name.to_s
    end

    def oof(rule, message, node_name)
      { "rule" => rule, "message" => message, "node" => node_name, "line" => nil }
    end

    # ── LANG-PLUGIN-SHAPE-CONFORMANCE-P2: `implements <Shape>` port conformance ──
    #
    # v0 semantics (see lab-docs/lang/lab-plugin-shape-conformance-p2-v0.md):
    #   * the named `contract_shape` must exist;
    #   * contract inputs match shape inputs by count, name, and type;
    #   * contract outputs match shape outputs by count and type;
    #   * any mismatch fails closed with OOF-SHAPE1 (no runtime behavior change).
    #
    # Scope: concrete (non-generic) shapes only. A generic `implements Shape[T]`
    # or a `contract_shape` with type_params is skipped in v0 (the specialized
    # ports would be derived from the shape). Parity with the Rust
    # `check_shape_conformance` pass.
    def shape_conformance_errors(classified_program)
      contracts = classified_program.fetch("contracts")
      return [] if contracts.none? { |c| c["implements"] }

      shapes = classified_program.fetch("contract_shapes", [])
      shape_index = shapes.each_with_object({}) { |s, h| h[s.fetch("name")] = s }
      errors = []

      contracts.each do |contract|
        impl = contract["implements"]
        next unless impl
        # v0: concrete shapes only (generic instantiation is out of scope).
        next unless (impl.fetch("type_args", []) || []).empty?

        shape_name = impl.fetch("name")
        shape = shape_index[shape_name]
        unless shape
          errors << oof("OOF-SHAPE1",
                        "Contract '#{contract.fetch("name")}' implements unknown shape '#{shape_name}': no `contract_shape #{shape_name}` is declared in scope",
                        contract.fetch("name"))
          next
        end
        next unless (shape.fetch("type_params", []) || []).empty?

        shape_inputs  = shape_body_ports(shape.fetch("body", []), "input")
        shape_outputs = shape_body_ports(shape.fetch("body", []), "output")
        c_inputs      = classified_contract_ports(contract, "input")
        c_outputs     = classified_contract_ports(contract, "output")

        mismatches = []

        if c_inputs.length != shape_inputs.length
          mismatches << "input count mismatch (shape declares #{shape_inputs.length}, contract declares #{c_inputs.length})"
        else
          shape_inputs.each_with_index do |(sh_name, sh_ty), i|
            c_name, c_ty = c_inputs[i]
            if c_name != sh_name
              mismatches << "input #{i + 1} name mismatch (shape '#{sh_name}', contract '#{c_name}')"
            elsif c_ty != sh_ty
              mismatches << "input '#{sh_name}' type mismatch (shape #{shape_type_to_s(sh_ty)}, contract #{shape_type_to_s(c_ty)})"
            end
          end
        end

        if c_outputs.length != shape_outputs.length
          mismatches << "output count mismatch (shape declares #{shape_outputs.length}, contract declares #{c_outputs.length})"
        else
          shape_outputs.each_with_index do |(_sh_name, sh_ty), i|
            _c_name, c_ty = c_outputs[i]
            mismatches << "output #{i + 1} type mismatch (shape #{shape_type_to_s(sh_ty)}, contract #{shape_type_to_s(c_ty)})" if c_ty != sh_ty
          end
        end

        unless mismatches.empty?
          errors << oof("OOF-SHAPE1",
                        "Contract '#{contract.fetch("name")}' does not conform to shape '#{shape_name}': #{mismatches.join("; ")}",
                        contract.fetch("name"))
        end
      end

      errors
    end

    # Ordered (name, type_annotation) ports of a contract_shape body for `kind`.
    def shape_body_ports(body, kind)
      body.select { |d| d.fetch("kind") == kind }
          .map { |d| [d.fetch("name"), d["type_annotation"]] }
    end

    # Ordered (name, type_annotation) input/output ports of a classified contract.
    # The classifier stores input/output `type_annotation` unchanged, so these
    # compare directly against `shape_body_ports`.
    def classified_contract_ports(contract, kind)
      contract.fetch("declarations", [])
              .select { |d| d.fetch("kind") == kind }
              .map { |d| [d.fetch("name"), d["type_annotation"]] }
    end

    # Render a parsed type annotation (String like "Integer" or Hash like
    # {"name"=>"Collection","params"=>[...]}) as a readable string for diagnostics.
    def shape_type_to_s(type)
      return type.to_s unless type.is_a?(Hash)

      name = type["name"] || type["constructor"] || "?"
      params = type["params"] || []
      return name.to_s if params.empty?

      "#{name}[#{params.map { |p| shape_type_to_s(p) }.join(",")}]"
    end

    # OOF-L4: detect self-recursion in a def function body (parity with Rust is_recursive()).
    # Only self-recursion is checked; mutual recursion is a P2 design question (SCC detection).
    def fn_self_recursive?(fn)
      fn_name = fn.fetch("name")
      fn_body_has_call?(fn.fetch("body", {}), fn_name)
    end

    def fn_body_has_call?(body, fn_name)
      return false unless body.is_a?(Hash)
      stmts = body.fetch("stmts", [])
      return_expr = body.fetch("return_expr", nil)
      stmts.any? { |stmt| fn_expr_has_call?(stmt.fetch("expr", stmt), fn_name) } ||
        (return_expr && fn_expr_has_call?(return_expr, fn_name))
    end

    def fn_expr_has_call?(expr, fn_name)
      return false unless expr.is_a?(Hash)
      case expr.fetch("kind", nil)
      when "call"
        expr.fetch("fn", nil) == fn_name ||
          expr.fetch("args", []).any? { |arg| fn_expr_has_call?(arg, fn_name) }
      when "binary_op"
        fn_expr_has_call?(expr["left"], fn_name) || fn_expr_has_call?(expr["right"], fn_name)
      when "unary_op"
        fn_expr_has_call?(expr["operand"], fn_name)
      when "field_access"
        fn_expr_has_call?(expr["object"], fn_name)
      when "index_access"
        fn_expr_has_call?(expr["object"], fn_name) || fn_expr_has_call?(expr["index"], fn_name)
      when "if_expr"
        fn_expr_has_call?(expr["cond"], fn_name) ||
          fn_body_has_call?(expr["then"], fn_name) ||
          fn_body_has_call?(expr["else"], fn_name)
      else
        false
      end
    end

    # Collect all calls to known def functions reachable from a body (SCC graph edges).
    # Returns a sorted, deduplicated Array of function names called within body_hash.
    def fn_extract_all_calls(body_hash, fn_names_set)
      found = Set.new
      fn_collect_calls_body(body_hash, fn_names_set, found)
      found.to_a.sort
    end

    def fn_collect_calls_expr(expr, fn_names_set, found)
      return unless expr.is_a?(Hash)
      case expr.fetch("kind", nil)
      when "call"
        callee = expr.fetch("fn", nil)
        found.add(callee) if callee && fn_names_set.include?(callee)
        expr.fetch("args", []).each { |arg| fn_collect_calls_expr(arg, fn_names_set, found) }
      when "binary_op"
        fn_collect_calls_expr(expr["left"], fn_names_set, found)
        fn_collect_calls_expr(expr["right"], fn_names_set, found)
      when "unary_op"
        fn_collect_calls_expr(expr["operand"], fn_names_set, found)
      when "field_access"
        fn_collect_calls_expr(expr["object"], fn_names_set, found)
      when "index_access"
        fn_collect_calls_expr(expr["object"], fn_names_set, found)
        fn_collect_calls_expr(expr["index"], fn_names_set, found)
      when "if_expr"
        fn_collect_calls_expr(expr["cond"], fn_names_set, found)
        fn_collect_calls_body(expr["then"], fn_names_set, found)
        fn_collect_calls_body(expr["else"], fn_names_set, found)
      end
    end

    def fn_collect_calls_body(body, fn_names_set, found)
      return unless body.is_a?(Hash)
      stmts = body.fetch("stmts", [])
      return_expr = body.fetch("return_expr", nil)
      stmts.each { |stmt| fn_collect_calls_expr(stmt.fetch("expr", stmt), fn_names_set, found) }
      fn_collect_calls_expr(return_expr, fn_names_set, found) if return_expr
    end

    # Tarjan's SCC algorithm — deterministic (sorted nodes, sorted neighbors, sorted SCC members).
    # Returns Array[Array[String]] — each inner array is one SCC, members sorted alphabetically.
    def tarjan_sccs(nodes, adj)
      idx = {}; low = {}; on_stack = Set.new
      stack = []; counter = [0]; sccs = []
      visit = nil
      visit = lambda do |v|
        idx[v] = low[v] = counter[0]; counter[0] += 1
        stack.push(v); on_stack.add(v)
        (adj[v] || []).sort.each do |w|
          if !idx.key?(w)
            visit.call(w); low[v] = [low[v], low[w]].min
          elsif on_stack.include?(w)
            low[v] = [low[v], idx[w]].min
          end
        end
        if low[v] == idx[v]
          scc = []
          loop { w = stack.pop; on_stack.delete(w); scc << w; break if w == v }
          sccs << scc.sort
        end
      end
      nodes.sort.each { |n| visit.call(n) unless idx.key?(n) }
      sccs
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
      # PROP-034: evidence refs passthrough
      result["evidence"] = decl.fetch("evidence") if decl.key?("evidence")
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

    # ── igniter-string-core-units-and-pure-stdlib-boundary-v0: text stdlib ────

    # Validate and type-infer a call to a text stdlib function.
    # Emits OOF-TY0 for arity mismatch or argument type mismatch.
    # Resolves fn name to the canonical "stdlib.text.<fn>" IR path.
    def infer_text_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      spec           = TEXT_STDLIB_FNS.fetch(fn)
      expected_count = spec[:arg_types].length

      # Arity check — early return with empty args if wrong
      if args.length != expected_count
        type_errors << oof(
          "OOF-TY0",
          "stdlib.text.#{fn}: expected #{expected_count} argument(s), got #{args.length}",
          node_name
        )
        return typed_expr("call", text_stdlib_return_type(spec[:return_type]), [],
                          "fn" => "stdlib.text.#{fn}", "args" => [])
      end

      # Infer and validate each argument
      typed_args = args.each_with_index.map do |arg, idx|
        ta       = infer_expr(arg, symbol_types, type_errors, type_warnings, node_name)
        actual   = type_name(ta.fetch("resolved_type"))
        expected = spec[:arg_types][idx]
        unless actual == "Unknown" || text_arg_compatible?(actual, expected)
          type_errors << oof(
            "OOF-TY0",
            "stdlib.text.#{fn} arg #{idx + 1}: expected #{expected}, got #{actual}",
            node_name
          )
        end
        ta
      end

      deps = typed_args.flat_map { |ta| ta.fetch("deps") }.uniq
      typed_expr("call", text_stdlib_return_type(spec[:return_type]), deps,
                 "fn" => "stdlib.text.#{fn}", "args" => typed_args)
    end

    # Build the return type IR for a text stdlib function.
    # "Collection[Text]" needs to be constructed as a parameterised type;
    # all other return types are simple names handled by type_ir().
    def text_stdlib_return_type(name)
      if name == "Collection[Text]"
        { "name" => "Collection", "params" => [{ "name" => "Text", "params" => [] }] }
      else
        type_ir(name)
      end
    end

    # v0 compatibility rule: Text ≡ String for text stdlib argument positions.
    # String literals from the parser carry type_tag "String"; they must be
    # accepted where "Text" is expected without a type error.
    # For non-Text expected types (Integer, Bool), exact match is required.
    def text_arg_compatible?(actual, expected)
      return actual == expected unless expected == "Text"
      %w[Text String].include?(actual)
    end

    # LANG-STDLIB-NUMERIC-TEXT-CONVERSION-P1: parse_int / int_to_text / modulo.
    # Resolves any recognized source alias (bare / stdlib.numeric.* / stdlib.integer.*) to the
    # canonical stdlib.integer.* SIR name; arity + arg-type checks emit the OOF-TY0 family (same as
    # the text ops). Domain errors (divide-by-zero, overflow) are runtime (VM), not typecheck-time.
    def infer_numeric_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      bare      = NUMERIC_STDLIB_ALIASES.fetch(fn)
      spec      = NUMERIC_STDLIB_FNS.fetch(bare)
      qualified = spec[:qualified_name]
      expected  = spec[:arg_types]
      ret_ir    = numeric_stdlib_return_type(spec[:return_type])

      if args.length != expected.length
        type_errors << oof(
          "OOF-TY0",
          "#{qualified}: expected #{expected.length} argument(s), got #{args.length}",
          node_name
        )
        return typed_expr("call", ret_ir, [], "fn" => qualified, "args" => [])
      end

      typed_args = args.each_with_index.map do |arg, idx|
        ta     = infer_expr(arg, symbol_types, type_errors, type_warnings, node_name)
        actual = type_name(ta.fetch("resolved_type"))
        want   = expected[idx]
        unless actual == "Unknown" || text_arg_compatible?(actual, want)
          type_errors << oof(
            "OOF-TY0",
            "#{qualified} arg #{idx + 1}: expected #{want}, got #{actual}",
            node_name
          )
        end
        ta
      end

      deps = typed_args.flat_map { |ta| ta.fetch("deps") }.uniq
      typed_expr("call", ret_ir, deps, "fn" => qualified, "args" => typed_args)
    end

    # Return-type IR for a numeric stdlib fn. Only "Option[Integer]" (parse_int) needs a
    # parameterised construction; the rest are simple names handled by type_ir().
    def numeric_stdlib_return_type(name)
      if name == "Option[Integer]"
        { "name" => "Option", "params" => [{ "name" => "Integer", "params" => [] }] }
      else
        type_ir(name)
      end
    end

    # ── PROP-039 OOF-R3: syntactic decrease helpers ────────────────────────────

    # Returns true if the expression syntactically proves the variant decreases.
    # Accepted patterns (v0 whitelist):
    #   variant - positive_integer_literal   (arithmetic decrease)
    #   variant.tail                          (structural: Collection tail)
    #   variant.rest                          (structural: Collection rest)
    # All other forms → OOF-R3 fires.
    def syntactic_decrease?(expr, variant_name)
      return false unless expr.is_a?(Hash)
      case expr.fetch("kind", "")
      when "binary_op"
        op    = expr.fetch("op", "")
        left  = expr.fetch("left", {})
        right = expr.fetch("right", {})
        op == "-" &&
          left.is_a?(Hash)  && left.fetch("kind", "")    == "ref"     && left.fetch("name", "")     == variant_name &&
          right.is_a?(Hash) && right.fetch("kind", "")   == "literal" && right.fetch("type_tag", "") == "Integer"    &&
          right.fetch("value", 0).to_i > 0
      when "field_access"
        obj   = expr.fetch("object", {})
        field = expr.fetch("field", "")
        %w[tail rest].include?(field) &&
          obj.is_a?(Hash) && obj.fetch("kind", "") == "ref" && obj.fetch("name", "") == variant_name
      else
        false
      end
    end

    # Human-readable description of an expression for OOF-R3 messages.
    def syntactic_arg_desc(expr)
      return "unknown" unless expr.is_a?(Hash)
      case expr.fetch("kind", "")
      when "ref"           then expr.fetch("name", "?")
      when "literal"       then expr.fetch("value", "?").to_s
      when "binary_op"
        left  = syntactic_arg_desc(expr.fetch("left",  {}))
        right = syntactic_arg_desc(expr.fetch("right", {}))
        "#{left} #{expr.fetch("op", "?")} #{right}"
      when "field_access"
        "#{syntactic_arg_desc(expr.fetch("object", {}))}.#{expr.fetch("field", "?")}"
      else
        expr.fetch("kind", "expr")
      end
    end

    # ── PROP-039 gate 5: recur() helpers ───────────────────────────────────────

    def infer_recur_call(expr, symbol_types, type_errors, type_warnings, node_name)
      ctx = @recur_context

      # OOF-R1: invalid context
      unless ctx && ctx[:authorized]
        type_errors << oof("OOF-R1", "recur() in '#{node_name}' — invalid recur context: recur() is only valid inside a recursive or fuel_bounded contract", node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => "recur", "args" => [])
      end

      # OOF-R7: not single-output
      if ctx[:output_count] != 1
        type_errors << oof("OOF-R7", "recur() in '#{node_name}' — contract must have exactly one output (has #{ctx[:output_count]}); multi-output recur() deferred to v1", node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => "recur", "args" => [])
      end

      input_names = ctx[:input_names]
      args = expr.fetch("args", [])

      # OOF-R5: arity mismatch
      if args.length != input_names.length
        type_errors << oof("OOF-R5", "recur() arity mismatch in '#{node_name}' — #{args.length} arg(s) given, #{input_names.length} input(s) expected", node_name)
        # still try to lower args for partial IR
      else
        # OOF-R6: type mismatch per arg
        args.each_with_index do |arg, idx|
          input_name = input_names[idx]
          expected_type = symbol_types.fetch(input_name, type_ir("Unknown"))
          arg_typed = infer_expr(arg, symbol_types, type_errors, type_warnings, node_name)
          actual   = type_name(arg_typed.fetch("resolved_type"))
          expected = type_name(expected_type)
          if actual != "Unknown" && expected != "Unknown" && actual != expected
            type_errors << oof("OOF-R6", "recur() arg #{idx + 1} type mismatch in '#{node_name}' — expected #{expected}, got #{actual}", node_name)
          end
        end

        # OOF-R3: variant-position arg must syntactically decrease the declared decreases variant
        dv = ctx[:decreases_variant]
        if dv && !dv.include?(".")
          variant_pos = input_names.index(dv)
          if variant_pos && variant_pos < args.length
            variant_arg = args[variant_pos]
            unless syntactic_decrease?(variant_arg, dv)
              arg_desc = syntactic_arg_desc(variant_arg)
              type_errors << oof("OOF-R3",
                "recur() in '#{node_name}' — variant '#{dv}' (position #{variant_pos + 1}) " \
                "does not syntactically decrease: #{arg_desc}; " \
                "expected '#{dv} - N', '#{dv}.tail', or '#{dv}.rest'",
                node_name)
            end
          end
        end

        # PROP-041 T2: call-site structural-size check → OOF-R9
        if @t2_context&.fetch(:kind) == :t2_pass
          t2_call_site_check(expr, type_errors, node_name, @t2_context)
        end
        # PROP-042 T3: numeric measure call-site check → OOF-R11
        if @t3_context&.fetch(:kind) == :t3_pass
          t3_call_site_check(expr, type_errors, node_name, @t3_context)
        end
      end

      typed_args = args.map { |a| infer_expr(a, symbol_types, [], [], node_name) }
      output_type = ctx[:output_type] || type_ir("Unknown")
      typed_expr("call", output_type, [], "fn" => "recur", "args" => typed_args, "__recur" => true)
    end

    def expr_contains_recur?(expr)
      return false unless expr.is_a?(Hash)
      return true if expr.fetch("kind", "") == "call" && expr.fetch("fn", "") == "recur"
      expr.any? { |_k, v|
        v.is_a?(Hash) ? expr_contains_recur?(v) :
        v.is_a?(Array) ? v.any? { |item| expr_contains_recur?(item) } : false
      }
    end

    # ── PROP-039 gate 8: loop body helpers ─────────────────────────────────────

    # Return element type T from a Collection[T] type_ir value.
    # Returns type_ir("Unknown") for non-parameterised or non-Collection types.
    def element_type_from_collection(collection_type)
      return type_ir("Unknown") unless collection_type.is_a?(Hash)
      params = collection_type.fetch("params", [])
      first  = params.first
      return type_ir("Unknown") unless first
      first.is_a?(Hash) ? first : type_ir(first.to_s)
    end

    # True when expr is a static literal (Integer, Float, String, Bool, Nil).
    def literal_expr?(expr)
      return false unless expr.is_a?(Hash)
      expr.fetch("kind", "") == "literal"
    end

    # Validate loop body scope rules (gate 8).
    # Returns an array of OOF type_error hashes; empty if all valid.
    #   OOF-L5 — unsupported body form (nested loop, decreases, max_steps, etc.)
    #   OOF-L7 — body compute targets outer contract symbol (mutation attempt)
    #   OOF-L8 — lead binding shadows outer contract symbol or loop item
    def check_loop_body(loop_decl, outer_symbols, item_name, _item_type)
      errors     = []
      loop_name  = loop_decl.fetch("name")
      body       = loop_decl.fetch("body", [])
      lead_names = []

      body.each do |b|
        case b.fetch("kind", "")
        when "lead"
          name = b.fetch("name")
          # Must not shadow outer contract symbol
          if outer_symbols.key?(name)
            errors << oof("OOF-L8",
              "lead '#{name}' in loop '#{loop_name}' shadows outer contract symbol — not permitted in loop body v0",
              loop_name)
          end
          # Must not shadow loop item variable
          if name == item_name
            errors << oof("OOF-L8",
              "lead '#{name}' in loop '#{loop_name}' shadows loop item variable '#{item_name}'",
              loop_name)
          end
          # Initial must be a static literal
          initial = b.fetch("initial", nil)
          if initial && !literal_expr?(initial)
            errors << oof("OOF-L5",
              "lead '#{name}' in loop '#{loop_name}': initial value must be a static literal in v0",
              loop_name)
          end
          lead_names << name
        when "compute"
          target = b.fetch("name")
          # PROP-039 gate 5: recur() in loop body is OOF-R1 (loop is not a recursive context)
          if expr_contains_recur?(b.fetch("expr", nil))
            errors << oof("OOF-R1", "recur() in loop body '#{loop_name}' — loop body is not a recursive or fuel_bounded context", loop_name)
          end
          # compute must target a lead binding — not outer symbols, not item
          if target == item_name
            errors << oof("OOF-L7",
              "body compute in loop '#{loop_name}' targets loop item '#{target}' — item is read-only",
              loop_name)
          elsif outer_symbols.key?(target) && !lead_names.include?(target)
            errors << oof("OOF-L7",
              "body compute in loop '#{loop_name}' targets outer contract symbol '#{target}' — outer state is read-only",
              loop_name)
          elsif !lead_names.include?(target) && !outer_symbols.key?(target) && target != item_name
            # Target is neither a lead binding, outer symbol, nor item — undefined in body scope
            errors << oof("OOF-L5",
              "body compute in loop '#{loop_name}' targets '#{target}' which is not a declared lead binding",
              loop_name)
          end
        when "for_loop", "budgeted_loop"
          errors << oof("OOF-L5",
            "nested loop '#{b.fetch("name", "?")}' in loop body '#{loop_name}' is not supported in v0",
            loop_name)
        when "decreases", "max_steps"
          errors << oof("OOF-L5",
            "'#{b.fetch("kind")}' is not valid inside a loop body (belongs to recursive contracts)",
            loop_name)
        when "invoke"
          # PROP-050 / OOF-EC6: invoke is body-declaration position ONLY — a
          # loop-body invoke would make the effect count data-dependent; effect
          # order must stay a static total order (declaration order). Lambda /
          # branch positions cannot parse by construction; loops reuse the body
          # grammar, so the position rule is enforced here.
          errors << oof("OOF-EC6",
            "invoke '#{b.fetch("binding", "?")}' inside loop body '#{loop_name}' — invoke is " \
            "valid only at contract-body declaration position (PROP-050)",
            loop_name)
        end
      end

      errors
    end

    # ── PROP-041 T2: structural-size relation helpers ────────────────────────────

    # Build the per-typecheck-run size registry: STDLIB entries + user module entries.
    # Keys are [TypeName, accessor] pairs; values are trust/source hashes.
    # source for user entries = module name (mirrors proof-local T2Pipeline#build_registry).
    def build_size_registry(classified_program)
      registry   = STDLIB_SIZE_REGISTRY.dup
      mod_name   = classified_program.fetch("module", "unknown")
      classified_program.fetch("size_relations", []).each do |decl|
        key = [decl.fetch("type"), decl.fetch("accessor")]
        registry[key] = { "trust" => "user_assumed", "source" => mod_name }
      end
      registry
    end

    # Handle a dotted-path decreases_variant for T2.
    # Sets @t2_context and fires OOF-R3 / OOF-R8 as appropriate.
    # Returns nil in all cases (dotted-path is never kept as a raw variant).
    # NOT a full termination proof — structural evidence with trust metadata only.
    def handle_t2_variant(dv, classified_contract, type_errors, contract_name_str)
      parts    = dv.split(".", 2)
      subject  = parts[0]
      accessor = parts[1]

      # Numeric dotted-path → OOF-R3 (original behavior, explicitly numeric-excluded)
      if NUMERIC_ACCESSORS.include?(accessor)
        type_errors << oof("OOF-R3",
          "recur() decreases variant '#{dv}' in '#{contract_name_str}' — " \
          "numeric accessor '#{accessor}' is not a structural-size relation; " \
          "use a simple numeric identifier as the decreases variant",
          contract_name_str)
        @t2_context = { kind: :t2_r3 }
        return nil
      end

      # Resolve subject's declared type from input declarations
      # classified_contract uses "declarations" (not a separate "inputs" key)
      all_decls  = classified_contract.fetch("declarations", [])
      input_decl = all_decls.find { |d| d.fetch("kind", "") == "input" && d.fetch("name", "") == subject }
      type_name_str = if input_decl
        raw = input_decl.fetch("type_annotation", "Unknown")
        # In the production pipeline type_annotation is a type_ir hash:
        # { "kind" => "type_ref", "name" => "Collection", "params" => [...] }
        # In the proof-local pipeline it may be a plain string.
        if raw.is_a?(Hash)
          raw.fetch("name", "Unknown")
        else
          raw.to_s.split("[", 2).first.strip
        end
      else
        "Unknown"
      end

      # Registry lookup: [TypeName, accessor]
      entry = @size_registry[[type_name_str, accessor]]

      if entry
        # T2 pass — store context for infer_expr whitelist + emitter propagation
        @t2_context = {
          kind:     :t2_pass,
          dv:       dv,
          subject:  subject,
          accessor: accessor,
          entry:    entry
        }
      else
        # OOF-R8: registered relation missing
        type_errors << oof("OOF-R8",
          "Missing structural size relation for '#{dv}' in '#{contract_name_str}' — " \
          "no size_relation declaration for #{type_name_str}.#{accessor}; " \
          "add 'size_relation #{type_name_str} #{accessor}' at module level",
          contract_name_str)
        @t2_context = { kind: :t2_r8 }
      end
      nil
    end

    # Call-site check for T2 recur() calls: variant-position arg must be subject.accessor.
    # Fires OOF-R9 on mismatch.
    def t2_call_site_check(expr, type_errors, node_name, ctx)
      recur_ctx = @recur_context
      return unless recur_ctx

      input_names = recur_ctx[:input_names]
      subject_pos = input_names.index(ctx[:subject])
      return unless subject_pos

      args = expr.fetch("args", [])
      return if subject_pos >= args.length

      variant_arg = args[subject_pos]
      unless t2_structural_arg?(variant_arg, ctx[:subject], ctx[:accessor])
        arg_desc = syntactic_arg_desc(variant_arg)
        type_errors << oof("OOF-R9",
          "recur() in '#{node_name}' — structural size call-site mismatch: " \
          "expected '#{ctx[:subject]}.#{ctx[:accessor]}' at argument position #{subject_pos + 1}, " \
          "got: #{arg_desc}; the recur() argument must be the declared structural accessor",
          node_name)
      end
    end

    # True when expr is exactly `subject.accessor` (field_access on a ref).
    def t2_structural_arg?(expr, subject, accessor)
      return false unless expr.is_a?(Hash) && expr.fetch("kind", "") == "field_access"
      return false unless expr.fetch("field", "") == accessor
      obj = expr.fetch("object", {})
      obj.is_a?(Hash) && obj.fetch("kind", "") == "ref" && obj.fetch("name", "") == subject
    end

    # ── PROP-042 T3: numeric measure dispatch and call-site check ───────────────

    # Handle a function-call form decreases variant for T3.
    # Sets @t3_context and fires OOF-R10 for unrecognized measure functions.
    # Returns nil in all cases (function-call form is never kept as a raw variant).
    # NOT a full termination proof — numeric evidence with trust metadata only.
    def handle_t3_variant(dv, classified_contract, type_errors, contract_name_str)
      m        = T3_CALL_FORM_RE.match(dv)
      fn_name  = m[1]
      arg_name = m[2]

      builtin = NUMERIC_MEASURE_BUILTINS[fn_name]
      unless builtin
        # OOF-R10: function-call decreases with fn not in NUMERIC_MEASURE_BUILTINS v0
        type_errors << oof("OOF-R10",
          "contract '#{contract_name_str}' — decreases measure '#{fn_name}(#{arg_name})': " \
          "'#{fn_name}' is not a recognized stdlib numeric measure in v0; allowed: count; " \
          "user-defined measures and Text length measures require future authorization",
          contract_name_str)
        @t3_context = { kind: :t3_r10 }
        return nil
      end

      # Resolve measured input's declared type from input declarations
      all_decls  = classified_contract.fetch("declarations", [])
      input_decl = all_decls.find { |d| d.fetch("kind", "") == "input" && d.fetch("name", "") == arg_name }
      subject_type = if input_decl
        raw = input_decl.fetch("type_annotation", "Unknown")
        if raw.is_a?(Hash)
          raw.fetch("name", "Unknown")
        else
          raw.to_s.split("[", 2).first.strip
        end
      else
        "Unknown"
      end

      # T3 pass context — used by infer_expr (OOF-P1 suppression) and t3_call_site_check (OOF-R11)
      @t3_context = {
        kind:         :t3_pass,
        dv:           dv,
        fn_name:      fn_name,
        arg_name:     arg_name,
        subject_type: subject_type,
        builtin:      builtin
      }
      nil
    end

    # Call-site check for T3 recur() calls.
    # The argument at the measured-input position must be a T2-registered structural
    # subvalue of the measured input. Fires OOF-R11 on failure.
    # Structural coverage implies numeric decrease via stdlib_numeric_certified axioms:
    #   count(x.tail) < count(x),  count(x.rest) < count(x).
    def t3_call_site_check(expr, type_errors, node_name, ctx)
      recur_ctx = @recur_context
      return unless recur_ctx

      input_names = recur_ctx[:input_names]
      subject_pos = input_names.index(ctx[:arg_name])
      return unless subject_pos

      args = expr.fetch("args", [])
      return if subject_pos >= args.length

      variant_arg = args[subject_pos]
      unless t3_structurally_covered?(variant_arg, ctx[:arg_name], ctx[:subject_type])
        arg_desc = syntactic_arg_desc(variant_arg)
        fn_name  = ctx[:fn_name]
        arg_name = ctx[:arg_name]
        type_errors << oof("OOF-R11",
          "recur() in '#{node_name}' — numeric measure decrease obligation not satisfied for " \
          "'#{fn_name}(#{arg_name})': argument at position #{subject_pos + 1} does not satisfy " \
          "#{fn_name}(arg) < #{fn_name}(#{arg_name}); expected a T2-registered structural " \
          "subvalue of '#{arg_name}' (e.g., #{arg_name}.tail or #{arg_name}.rest for " \
          "Collection, or a declared size_relation for the type)",
          node_name)
      end
    end

    # True iff expr is a field_access on subject_name whose accessor is registered
    # in the T2 size_registry for subject_type.
    # Delegates structural coverage to the T2 registry (stdlib + user-declared).
    def t3_structurally_covered?(expr, subject_name, subject_type)
      return false unless expr.is_a?(Hash) && expr.fetch("kind", "") == "field_access"

      obj = expr.fetch("object", {})
      fld = expr.fetch("field", "")
      return false unless obj.is_a?(Hash) &&
                          obj.fetch("kind", "") == "ref" &&
                          obj.fetch("name", "") == subject_name

      @size_registry.key?([subject_type, fld])
    end

    # ── PROP-043: Map[String,V] stdlib — private implementation ──────────────────

    # Dispatcher for MAP_STDLIB_FNS.keys.
    # Routes fn to the appropriate infer_map_* handler.
    def infer_map_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      case fn
      when "map_get"
        infer_map_get(args, symbol_types, type_errors, type_warnings, node_name)
      when "map_has_key"
        infer_map_has_key(args, symbol_types, type_errors, type_warnings, node_name)
      when "map_from_pairs"
        infer_map_from_pairs(args, symbol_types, type_errors, type_warnings, node_name)
      when "map_empty"
        infer_map_empty(args, symbol_types, type_errors, type_warnings, node_name)
      else
        type_errors << oof("OOF-TY0", "Unknown map function: #{fn}", node_name)
        typed_expr("call", type_ir("Unknown"), [], "fn" => fn, "args" => [])
      end
    end

    # Rule MAP-GET: map_get(Map[String,V], String) → Option[V]
    # V extracted from Map params[1]. Unknown-compat: Option[Unknown] for Unknown map.
    def infer_map_get(args, symbol_types, type_errors, type_warnings, node_name)
      unless args.length == 2
        type_errors << oof("OOF-TY0", "map_get requires 2 arguments (map, key)", node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => "stdlib.map.get", "args" => [])
      end

      map_arg = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      key_arg = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)

      map_type = map_arg.fetch("resolved_type")
      unless type_name(map_type) == "Map" || type_name(map_type) == "Unknown"
        type_errors << oof(
          "OOF-TY0",
          "map_get: first argument must be Map[String,V], got #{type_name(map_type)}",
          node_name
        )
      end

      value_type = if type_name(map_type) == "Map"
        params = map_type.fetch("params", [])
        params.length >= 2 ? params[1] : type_ir("Unknown")
      else
        type_ir("Unknown")
      end

      deps = (map_arg.fetch("deps", []) + key_arg.fetch("deps", [])).uniq
      typed_expr("call", option_type_ir(value_type), deps,
                 "fn" => "stdlib.map.get", "args" => [map_arg, key_arg])
    end

    # Rule MAP-HAS-KEY: map_has_key(Map[String,V], String) → Bool
    # Always Bool regardless of V. Unknown-compat: Bool even for Unknown map.
    def infer_map_has_key(args, symbol_types, type_errors, type_warnings, node_name)
      unless args.length == 2
        type_errors << oof("OOF-TY0", "map_has_key requires 2 arguments (map, key)", node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => "stdlib.map.has_key", "args" => [])
      end

      map_arg = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      key_arg = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)

      map_type = map_arg.fetch("resolved_type")
      unless type_name(map_type) == "Map" || type_name(map_type) == "Unknown"
        type_errors << oof(
          "OOF-TY0",
          "map_has_key: first argument must be Map[String,V], got #{type_name(map_type)}",
          node_name
        )
      end

      deps = (map_arg.fetch("deps", []) + key_arg.fetch("deps", [])).uniq
      typed_expr("call", type_ir("Bool"), deps,
                 "fn" => "stdlib.map.has_key", "args" => [map_arg, key_arg])
    end

    # Rule MAP-FROM-PAIRS: map_from_pairs(Collection[PairRecord]) → Map[String,V]
    # V inferred from @type_shapes[elem]["value"]. Silent Unknown fallback on unrecognized elem.
    def infer_map_from_pairs(args, symbol_types, type_errors, type_warnings, node_name)
      unless args.length == 1
        type_errors << oof("OOF-TY0", "map_from_pairs requires 1 argument (pairs)", node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => "stdlib.map.from_pairs", "args" => [])
      end

      pairs_arg  = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      pairs_type = pairs_arg.fetch("resolved_type")
      value_type = infer_from_pairs_value_type(pairs_type)

      typed_expr("call", map_type_ir("String", value_type), pairs_arg.fetch("deps", []),
                 "fn" => "stdlib.map.from_pairs", "args" => [pairs_arg])
    end

    # Infer value type V from a Collection[PairRecord] type for map_from_pairs.
    # Looks up @type_shapes[elem_name]["value"]. Silent Unknown on any miss.
    def infer_from_pairs_value_type(pairs_type)
      return type_ir("Unknown") unless type_name(pairs_type) == "Collection"

      elem_params = pairs_type.fetch("params", [])
      return type_ir("Unknown") if elem_params.empty?

      elem_type_name = type_name(elem_params[0])
      if @type_shapes&.key?(elem_type_name)
        value_field = @type_shapes[elem_type_name]["value"]
        return value_field if value_field
      end

      type_ir("Unknown")
    end

    # Rule MAP-EMPTY: map_empty() → Map[String,Unknown]
    # Context-driven V inference deferred to v1. V=Unknown is the accepted v0 behavior.
    # map_empty() flows to output Map[String,String] without OOF — output check uses
    # type_name equality only ("Map" == "Map"); param unification is v1.
    def infer_map_empty(args, symbol_types, type_errors, type_warnings, node_name)
      unless args.empty?
        type_errors << oof("OOF-TY0", "map_empty takes no arguments", node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => "stdlib.map.empty", "args" => [])
      end

      typed_expr("call", map_type_ir("String", "Unknown"), [],
                 "fn" => "stdlib.map.empty", "args" => [],
                 "note" => "empty-type-context-inference-deferred-v1")
    end

    # ── LANG-STDLIB-OUTCOME-PROP-P3: stdlib.outcome helpers ─────────────────────

    # Shared handler for all OUTCOME_STDLIB_FNS entries.
    # All 7 helpers: arity 1, Map[String,String] or Unknown input, Bool or String output.
    # OOF-TY0 for arity mismatch (consistent with TEXT and MAP stdlib patterns).
    # OOF-OUT1 for non-Map argument type (first outcome-specific diagnostic code).
    # Unknown input: accepted leniently to avoid cascading errors on unresolved refs.
    # Domain-local kind values are not inspected at TypeChecker level — any Map passes.
    # SemanticIR fn is always the qualified canonical name from OUTCOME_STDLIB_FNS.
    def infer_outcome_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      spec           = OUTCOME_STDLIB_FNS.fetch(fn)
      qualified_name = spec[:qualified_name]
      return_type    = spec[:return_type]

      unless args.length == 1
        type_errors << oof("OOF-TY0",
          "#{qualified_name}: expected 1 argument (Map[String, String]), got #{args.length}",
          node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => qualified_name, "args" => [])
      end

      outcome_arg = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      actual_name = type_name(outcome_arg.fetch("resolved_type"))
      unless actual_name == "Unknown" || actual_name == "Map"
        type_errors << oof("OOF-OUT1",
          "#{qualified_name}: argument must be Map[String, String], got #{actual_name}",
          node_name)
      end

      typed_expr("call", type_ir(return_type), outcome_arg.fetch("deps", []),
                 "fn" => qualified_name, "args" => [outcome_arg])
    end

    # LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P1: Collection HOF dispatch.
    # map(Collection[T],  (T→U))       → Collection[U]
    # filter(Collection[T], (T→Bool))  → Collection[T]
    # count(Collection[T])             → Integer
    # find(Collection[T], (T→Bool))    → Option[T]
    # any/all(Collection[T], (T→Bool)) → Bool
    def infer_collection_hof_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      spec           = COLLECTION_HOF_FNS.fetch(fn)
      qualified      = spec[:qualified_name]
      expected_arity = spec[:arity]
      has_lambda     = spec[:has_lambda]

      # ── OOF-COL1: arity check ────────────────────────────────────────────────
      unless args.length == expected_arity
        type_errors << oof("OOF-COL1",
          "#{qualified}: expected #{expected_arity} argument(s), got #{args.length}",
          node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => qualified, "args" => [])
      end

      # ── Infer collection argument ─────────────────────────────────────────────
      collection_arg = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      col_type_name  = type_name(collection_arg.fetch("resolved_type"))

      # ── OOF-COL2: first arg must be Collection or Unknown ─────────────────────
      unless col_type_name == "Collection" || col_type_name == "Unknown"
        type_errors << oof("OOF-COL2",
          "#{qualified}: first argument must be Collection[T], got #{col_type_name}",
          node_name)
        recovery_type = %w[any all].include?(fn) ? type_ir("Bool") : type_ir("Unknown")
        return typed_expr("call", recovery_type, collection_arg.fetch("deps", []),
                          "fn" => qualified, "args" => [collection_arg])
      end

      # ── count: no lambda, return Integer ─────────────────────────────────────
      unless has_lambda
        return typed_expr("call", type_ir("Integer"), collection_arg.fetch("deps", []),
                          "fn" => qualified, "args" => [collection_arg])
      end

      # ── map / filter / predicate ops: validate lambda argument ────────────────
      lambda_node = args[1]
      unless lambda_node.is_a?(Hash) && lambda_node.fetch("kind", nil) == "lambda"
        type_errors << oof("OOF-COL1",
          "#{qualified}: second argument must be a lambda, got #{lambda_node.fetch("kind", "non-lambda") rescue "non-lambda"}",
          node_name)
        recovery_type = %w[any all].include?(fn) ? type_ir("Bool") : type_ir("Unknown")
        return typed_expr("call", recovery_type, collection_arg.fetch("deps", []),
                          "fn" => qualified, "args" => [collection_arg])
      end

      # ── Bind lambda parameter to element type ─────────────────────────────────
      elem_type     = element_type_from_collection(collection_arg.fetch("resolved_type"))
      lambda_params = lambda_node.fetch("params", [])
      local_symbols = lambda_params.each_with_object(symbol_types.dup) do |param, acc|
        acc[param] = elem_type
      end

      # ── Infer lambda body ─────────────────────────────────────────────────────
      lambda_body = lambda_node.fetch("body")
      body_typed  = infer_lambda_body(lambda_body, local_symbols, type_errors, type_warnings, node_name)
      body_type   = body_typed.fetch("resolved_type")

      # ── OOF-COL3: predicate ops must return Bool ─────────────────────────────
      if %w[filter find any all].include?(fn)
        pred_name = type_name(body_type)
        unless pred_name == "Bool" || pred_name == "Unknown"
          type_errors << oof("OOF-COL3",
            "#{qualified}: predicate must return Bool, got #{pred_name}",
            node_name)
        end
      end

      lambda_deps = body_typed.fetch("deps", [])
      all_deps    = (collection_arg.fetch("deps", []) + lambda_deps).uniq

      # ── Build output type ─────────────────────────────────────────────────────
      output_type = case fn
      when "map"    then collection_type_ir_from(body_type)
      when "filter" then collection_type_ir_from(elem_type)
      when "find"   then option_type_ir(elem_type)
      when "any", "all" then type_ir("Bool")
      when "flat_map"
        # LANG-STDLIB-COLLECTION-FLATMAP-P3: ONE-LEVEL unwrap. The lambda body is `Collection[B]`,
        # and the result is that SAME `Collection[B]` - NOT `collection_type_ir_from(body_type)`,
        # which would wrap it again as `Collection[Collection[B]]`.
        case type_name(body_type)
        when "Collection"
          body_type                                   # Collection[B] (or Collection[Unknown]) as-is
        when "Unknown"
          collection_type_ir_from(type_ir("Unknown")) # body fully Unknown -> permissive Collection[Unknown]
        else
          # -- OOF-COL9: flat_map lambda body must itself be a collection --------------------------
          type_errors << oof("OOF-COL9",
            "#{qualified}: lambda body must return Collection[B], got #{type_name(body_type)}",
            node_name)
          collection_type_ir_from(type_ir("Unknown")) # recover as Collection[Unknown]
        end
      end

      lambda_typed = {
        "kind" => "lambda",
        "params" => lambda_params,
        "body" => body_typed,
        "resolved_type" => body_type
      }

      typed_expr("call", output_type, all_deps,
                 "fn" => qualified, "args" => [collection_arg, lambda_typed])
    end

    # LANG-SUMTYPE-COLLECT-P3: filter_map(Collection[T], (T -> Option[U])) -> Collection[U].
    # Keeps each Some(u) payload, drops every None. Mirrors map/filter HOF handling:
    # OOF-COL1 (arity / non-lambda), OOF-COL2 (non-Collection first arg), OOF-COL3
    # (callback must return Option). U is preferred from the callback's own concrete
    # Option[U] param; when a parametric `match` callback collapses to bare Option
    # (the COLLECT-P1 sub-gap), U falls back to the Collection[U] output context
    # (@collection_output_hints, route B2). While inferring the callback body, the
    # expected Option[U] is temp-installed as a sealed hint so none()/some() resolve
    # against U. SIR mirrors map per-toolchain: qualified fn, lambda dropped from args.
    def infer_filter_map_call(args, symbol_types, type_errors, type_warnings, node_name)
      qualified = "stdlib.collection.filter_map"

      # ── OOF-COL1: arity must be exactly 2 ────────────────────────────────────
      unless args.length == 2
        type_errors << oof("OOF-COL1",
          "#{qualified}: expected 2 argument(s), got #{args.length}", node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => qualified, "args" => [])
      end

      # ── Infer collection argument ────────────────────────────────────────────
      collection_arg = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      col_type_name  = type_name(collection_arg.fetch("resolved_type"))

      # ── OOF-COL2: first arg must be Collection or Unknown ────────────────────
      unless col_type_name == "Collection" || col_type_name == "Unknown"
        type_errors << oof("OOF-COL2",
          "#{qualified}: first argument must be Collection[T], got #{col_type_name}", node_name)
        return typed_expr("call", type_ir("Unknown"), collection_arg.fetch("deps", []),
                          "fn" => qualified, "args" => [collection_arg])
      end

      # ── OOF-COL1: second arg must be a lambda ────────────────────────────────
      lambda_node = args[1]
      unless lambda_node.is_a?(Hash) && lambda_node.fetch("kind", nil) == "lambda"
        type_errors << oof("OOF-COL1",
          "#{qualified}: second argument must be a lambda, got #{lambda_node.fetch("kind", "non-lambda") rescue "non-lambda"}", node_name)
        return typed_expr("call", type_ir("Unknown"), collection_arg.fetch("deps", []),
                          "fn" => qualified, "args" => [collection_arg])
      end

      # ── Bind lambda parameter to element type T ──────────────────────────────
      elem_type     = element_type_from_collection(collection_arg.fetch("resolved_type"))
      lambda_params = lambda_node.fetch("params", [])
      local_symbols = lambda_params.each_with_object(symbol_types.dup) { |p, acc| acc[p] = elem_type }

      # ── Route B2: U from Collection[U] output context; install Option[U] hint ─
      ctx_u     = (@collection_output_hints || {})[node_name]
      temp_hint = false
      if ctx_u.is_a?(Hash) && type_name(ctx_u) != "Unknown" && !@sealed_output_hints.key?(node_name)
        @sealed_output_hints[node_name] = option_type_ir(ctx_u)
        temp_hint = true
      end
      begin
        body_typed = infer_lambda_body(lambda_node.fetch("body"), local_symbols, type_errors, type_warnings, node_name)
      ensure
        @sealed_output_hints.delete(node_name) if temp_hint
      end
      body_type = body_typed.fetch("resolved_type")

      # ── OOF-COL3: callback must return Option[U] ─────────────────────────────
      body_name = type_name(body_type)
      unless body_name == "Option" || body_name == "Unknown"
        type_errors << oof("OOF-COL3",
          "#{qualified}: callback must return Option[U], got #{body_name}", node_name)
      end

      # ── Result element U: callback's concrete Option param, else output context ─
      body_inner = element_type_from_collection(body_type)
      u_type =
        if body_inner.is_a?(Hash) && type_name(body_inner) != "Unknown"
          body_inner
        elsif ctx_u.is_a?(Hash) && type_name(ctx_u) != "Unknown"
          ctx_u
        else
          type_ir("Unknown")
        end

      all_deps = (collection_arg.fetch("deps", []) + body_typed.fetch("deps", [])).uniq
      lambda_typed = {
        "kind" => "lambda",
        "params" => lambda_params,
        "body" => body_typed,
        "resolved_type" => body_type
      }

      typed_expr("call", collection_type_ir_from(u_type), all_deps,
                 "fn" => qualified, "args" => [collection_arg, lambda_typed])
    end

    # LANG-STDLIB-COLLECTION-FIRST-LAST-P2: first(Collection[T]) / last(Collection[T]) -> Option[T].
    # Mirrors the current Rust TC behavior: no new arity/non-Collection diagnostics
    # here; malformed or non-inferable input falls back to Option[Unknown].
    def infer_collection_first_last_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      qualified = COLLECTION_FIRST_LAST_FNS.fetch(fn).fetch(:qualified_name)
      typed_args = args.map { |arg| infer_expr(arg, symbol_types, type_errors, type_warnings, node_name) }
      deps = typed_args.flat_map { |arg| arg.fetch("deps", []) }.uniq

      inner_type = type_ir("Unknown")
      if typed_args.any?
        extracted = element_type_from_collection(typed_args[0].fetch("resolved_type"))
        inner_type = extracted if extracted.is_a?(Hash) && !extracted.empty?
      end

      typed_expr("call", option_type_ir(inner_type), deps,
                 "fn" => qualified, "args" => typed_args)
    end

    # LANG-STDLIB-COLLECTION-ZIP-RUBY-PARITY-P3: zip(Collection[A], Collection[B]) ->
    # Collection[Pair[A, B]]. Canon Ruby registration of the surface already live on the lab Rust
    # compiler (stdlib_calls "zip") and the VM ({first, second} records, truncate-to-min).
    # OOF-COL1: arity != 2. OOF-COL2: non-Collection argument (Unknown stays permissive, mirroring
    # the Rust fallback Pair[Unknown, Unknown]).
    def infer_zip_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      qualified = "stdlib.collection.zip"
      typed_args = args.map { |arg| infer_expr(arg, symbol_types, type_errors, type_warnings, node_name) }
      deps = typed_args.flat_map { |arg| arg.fetch("deps", []) }.uniq

      unless args.length == 2
        type_errors << oof("OOF-COL1",
          "#{qualified}: expected 2 arguments (collection, collection), got #{args.length}",
          node_name)
        return typed_expr("call", type_ir("Unknown"), deps, "fn" => qualified, "args" => typed_args)
      end

      inners = typed_args.map do |typed|
        resolved = typed.fetch("resolved_type", {})
        arg_name = resolved.is_a?(Hash) ? resolved.fetch("name", "Unknown") : "Unknown"
        unless %w[Collection Unknown].include?(arg_name)
          type_errors << oof("OOF-COL2",
            "#{qualified}: expected Collection argument, got #{arg_name}",
            node_name)
        end
        extracted = element_type_from_collection(resolved)
        extracted.is_a?(Hash) && !extracted.empty? ? extracted : type_ir("Unknown")
      end

      pair_type = { "name" => "Pair", "params" => inners }
      typed_expr("call", { "name" => "Collection", "params" => [pair_type] }, deps,
                 "fn" => qualified, "args" => typed_args)
    end

    # LANG-STDLIB-SUM-PROP-P3: stdlib.collection.sum two-arg field-projection form.
    # sum(Collection[T], Symbol) -> F where F = @type_shapes[T][field_name]
    # Scale-preserving for Decimal[N]: F is the declared type_ir, not an arithmetic result.
    # OOF-COL1: arity != 2
    # OOF-COL2: non-Collection first arg
    # OOF-COL5: non-Symbol second arg OR field not found in type_shapes (Unknown elem exempt)
    # LANG-STDLIB-COLLECTION-SUM-SCALAR-P2: sum has two forms, dispatched by arity:
    #   1-arg scalar:           sum(Collection[T])         -> T        (T must be Numeric)
    #   2-arg field projection: sum(Collection[T], :field) -> F        (existing)
    # Scalar sum returns the element type EXACTLY (Decimal scale preserved); the empty
    # identity is the additive zero of T's family (LANG-STDLIB-COLLECTION-SUM-SCALAR-P1).
    NUMERIC_SUM_FAMILIES = %w[Integer Float Decimal Unknown].freeze

    # LANG-EFFECT-SURFACE-RECEIPT-FAILURE-P1: scalar types a receipt/failure clause
    # may reference without a module-level type/variant declaration.
    EFFECT_SURFACE_BUILTIN_TYPES = %w[Integer Float Decimal Bool Text String Unit].freeze

    # LANG-EFFECT-SURFACE-REQUIRED-FIELDS-P28: which contract modifiers carry an
    # Effect Surface (and are thus subject to the completeness gate) and which
    # declaration `kind`s are required for each. `compensation` is intentionally
    # absent — its requiredness lives in the OOF-M3 warn. `authority` is required
    # only for `privileged`/`irreversible` (declared-intent, never runtime).
    EFFECT_FAMILY_MODIFIERS = %w[effect privileged irreversible].freeze
    REQUIRED_EFFECT_SURFACE_FIELDS = {
      "affects"       => %w[effect privileged irreversible],
      "reversibility" => %w[effect privileged irreversible],
      "idempotency"   => %w[effect privileged irreversible],
      "receipt"       => %w[effect privileged irreversible],
      "failure"       => %w[effect privileged irreversible],
      "authority"     => %w[privileged irreversible]
    }.freeze

    def infer_sum_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      qualified = "stdlib.collection.sum"

      # ── OOF-COL1: arity must be 1 (scalar) or 2 (field projection) ──────────
      unless args.length == 1 || args.length == 2
        type_errors << oof("OOF-COL1",
          "#{qualified}: expected 1 (collection) or 2 (collection, :field) argument(s), got #{args.length}",
          node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => qualified, "args" => [])
      end

      # ── Infer collection argument ────────────────────────────────────────────
      collection_arg = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      col_type_name  = type_name(collection_arg.fetch("resolved_type"))

      # ── OOF-COL2: first arg must be Collection or Unknown ───────────────────
      unless col_type_name == "Collection" || col_type_name == "Unknown"
        type_errors << oof("OOF-COL2",
          "#{qualified}: first argument must be Collection[T], got #{col_type_name}",
          node_name)
        return typed_expr("call", type_ir("Unknown"), collection_arg.fetch("deps", []),
                          "fn" => qualified, "args" => [collection_arg])
      end

      elem_type = element_type_from_collection(collection_arg.fetch("resolved_type"))

      # ── Scalar form: sum(Collection[T]) -> T (T must be Numeric) ─────────────
      if args.length == 1
        elem_name = type_name(elem_type)
        unless NUMERIC_SUM_FAMILIES.include?(elem_name)
          type_errors << oof("OOF-COL8",
            "#{qualified}: scalar sum element type must be Numeric (Integer, Float, Decimal[N]), got #{elem_name}",
            node_name)
          return typed_expr("call", type_ir("Unknown"), collection_arg.fetch("deps", []),
                            "fn" => qualified, "args" => [collection_arg])
        end
        return typed_expr("call", elem_type, collection_arg.fetch("deps", []),
                          "fn" => qualified, "args" => [collection_arg])
      end

      # ── OOF-COL5: second arg must be a Symbol literal ───────────────────────
      sym_node = args[1]
      unless sym_node.is_a?(Hash) && sym_node.fetch("kind", nil) == "symbol"
        got = sym_node.is_a?(Hash) ? sym_node.fetch("kind", "non-symbol") : "non-symbol"
        type_errors << oof("OOF-COL5",
          "#{qualified}: second argument must be a Symbol field name (:field), got #{got}",
          node_name)
        return typed_expr("call", type_ir("Unknown"), collection_arg.fetch("deps", []),
                          "fn" => qualified, "args" => [collection_arg])
      end
      field_name = sym_node.fetch("value")

      # ── Field type lookup from @type_shapes ─────────────────────────────────
      elem_type      = element_type_from_collection(collection_arg.fetch("resolved_type"))
      elem_type_name = type_name(elem_type)
      field_type     = @type_shapes.fetch(elem_type_name, {})[field_name]

      # ── OOF-COL5: missing field (Unknown elem type is permissive) ────────────
      if field_type.nil?
        unless elem_type_name == "Unknown"
          type_errors << oof("OOF-COL5",
            "#{qualified}: field ':#{field_name}' not found in type #{elem_type_name}",
            node_name)
        end
        field_type = type_ir("Unknown")
      end

      typed_expr("call", field_type, collection_arg.fetch("deps", []),
                 "fn" => qualified, "args" => [collection_arg])
    end

    # Infer the return type of a lambda body.
    # Handles both single-expression bodies and block-form bodies.
    def infer_lambda_body(body, local_symbols, type_errors, type_warnings, node_name)
      if body.is_a?(Hash) && body.fetch("kind", nil) == "block"
        stmts       = body.fetch("stmts", [])
        return_expr = body.fetch("return_expr", nil)
        block_syms  = local_symbols.dup
        stmts.each do |stmt|
          case stmt.fetch("kind", nil)
          when "let"
            val_typed = infer_expr(stmt.fetch("expr"), block_syms, type_errors, type_warnings, node_name)
            block_syms[stmt.fetch("name")] = val_typed.fetch("resolved_type")
          when "expr_stmt"
            infer_expr(stmt.fetch("expr"), block_syms, type_errors, type_warnings, node_name)
          end
        end
        return_expr ? infer_expr(return_expr, block_syms, type_errors, type_warnings, node_name)
                    : typed_expr("literal", type_ir("Unknown"), [], "value" => nil, "literal_type" => "nil")
      else
        infer_expr(body, local_symbols, type_errors, type_warnings, node_name)
      end
    end

    # LANG-STDLIB-FOLD-PROP-P1/P3: stdlib.collection.fold
    # Signature: Collection[T] × Acc × ((Acc, T) -> Acc) -> Acc
    # Acc type inferred from seed expression (args[1]).
    # Lambda must have exactly 2 params: acc → Acc, elem → T.
    # OOF-COL4 for all fold-family errors.
    def infer_fold_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      qualified = "stdlib.collection.fold"

      unless args.length == 3
        type_errors << oof("OOF-COL4",
          "#{qualified}: expected 3 arguments (collection, seed, lambda), got #{args.length}",
          node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => qualified, "args" => [])
      end

      collection_typed = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      col_type_name    = type_name(collection_typed.fetch("resolved_type"))

      unless col_type_name == "Collection" || col_type_name == "Unknown"
        type_errors << oof("OOF-COL4",
          "#{qualified}: first argument must be Collection[T], got #{col_type_name}",
          node_name)
        return typed_expr("call", type_ir("Unknown"), collection_typed.fetch("deps", []),
                          "fn" => qualified, "args" => [collection_typed])
      end

      seed_typed = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
      acc_type   = seed_typed.fetch("resolved_type")

      lambda_node = args[2]
      unless lambda_node.is_a?(Hash) && lambda_node.fetch("kind", nil) == "lambda"
        bad_kind = lambda_node.is_a?(Hash) ? lambda_node.fetch("kind", "non-lambda") : "non-lambda"
        type_errors << oof("OOF-COL4",
          "#{qualified}: third argument must be a lambda, got #{bad_kind}",
          node_name)
        col_seed_deps = (collection_typed.fetch("deps", []) + seed_typed.fetch("deps", [])).uniq
        return typed_expr("call", acc_type, col_seed_deps, "fn" => qualified,
                          "args" => [collection_typed, seed_typed])
      end

      lambda_params = lambda_node.fetch("params", [])
      unless lambda_params.length == 2
        type_errors << oof("OOF-COL4",
          "#{qualified}: lambda must have exactly 2 parameters (acc, elem), got #{lambda_params.length}",
          node_name)
        col_seed_deps = (collection_typed.fetch("deps", []) + seed_typed.fetch("deps", [])).uniq
        return typed_expr("call", acc_type, col_seed_deps, "fn" => qualified,
                          "args" => [collection_typed, seed_typed])
      end

      elem_type     = element_type_from_collection(collection_typed.fetch("resolved_type"))
      local_symbols = symbol_types.merge(lambda_params[0] => acc_type, lambda_params[1] => elem_type)

      lambda_body = lambda_node.fetch("body")
      body_typed  = infer_lambda_body(lambda_body, local_symbols, type_errors, type_warnings, node_name)
      body_type   = body_typed.fetch("resolved_type")

      body_name = type_name(body_type)
      acc_name  = type_name(acc_type)
      unless body_name == acc_name || body_name == "Unknown" || acc_name == "Unknown"
        type_errors << oof("OOF-COL4",
          "#{qualified}: lambda return type #{body_name} does not match accumulator type #{acc_name}",
          node_name)
      end

      all_deps = (collection_typed.fetch("deps", []) + seed_typed.fetch("deps", []) + body_typed.fetch("deps", [])).uniq
      lambda_typed = {
        "kind" => "lambda",
        "params" => lambda_params,
        "body" => body_typed,
        "resolved_type" => acc_type
      }
      typed_expr("call", acc_type, all_deps, "fn" => qualified, "args" => [collection_typed, seed_typed, lambda_typed])
    end

    # LANG-STDLIB-COLLECTION-APPEND-PROP-P3: stdlib.collection.append
    # append(Collection[T], T) -> Collection[T]
    # OOF-COL1: arity != 2
    # OOF-COL2: non-Collection / non-Unknown first arg
    # OOF-COL6: item type concrete mismatch (both concrete, different names)
    # Unknown permissive on both sides — no COL6 when either is Unknown.
    def infer_append_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      qualified = "stdlib.collection.append"

      # ── OOF-COL1: arity ──────────────────────────────────────────────────────
      unless args.length == 2
        type_errors << oof("OOF-COL1",
          "#{qualified}: expected 2 arguments, got #{args.length}",
          node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => qualified, "args" => [])
      end

      # ── Infer collection arg ──────────────────────────────────────────────────
      collection_arg = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      col_type_name  = type_name(collection_arg.fetch("resolved_type"))

      # ── OOF-COL2: first arg must be Collection or Unknown ─────────────────────
      unless col_type_name == "Collection" || col_type_name == "Unknown"
        type_errors << oof("OOF-COL2",
          "#{qualified}: first argument must be Collection[T], got #{col_type_name}",
          node_name)
        return typed_expr("call", type_ir("Unknown"), collection_arg.fetch("deps", []),
                          "fn" => qualified, "args" => [collection_arg])
      end

      # ── Infer item arg ────────────────────────────────────────────────────────
      item_arg  = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
      elem_type = element_type_from_collection(collection_arg.fetch("resolved_type"))
      elem_name = type_name(elem_type)
      item_name = type_name(item_arg.fetch("resolved_type"))

      # ── OOF-COL6: concrete type mismatch (Unknown permissive on both sides) ───
      unless elem_name == "Unknown" || item_name == "Unknown" || elem_name == item_name
        type_errors << oof("OOF-COL6",
          "#{qualified}: item type #{item_name} does not match collection element type #{elem_name}",
          node_name)
      end

      all_deps = (collection_arg.fetch("deps", []) + item_arg.fetch("deps", [])).uniq
      typed_expr("call", collection_type_ir_from(elem_type), all_deps,
                 "fn" => qualified, "args" => [collection_arg, item_arg])
    end

    # LANG-STDLIB-IS-EMPTY-PROP-P3: stdlib.collection.is_empty + stdlib.collection.non_empty
    # is_empty(Collection[T]) -> Bool  — true iff collection has zero elements
    # non_empty(Collection[T]) -> Bool — true iff collection has one or more elements
    # non_empty cannot be derived as !is_empty(x): unary_op not dispatched in infer_expr.
    # Bool returned on ALL paths including OOF error paths (no Unknown propagation).
    # OOF-COL1: arity != 1; OOF-COL2: non-Collection, non-Unknown first arg.
    def infer_is_empty_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      qualified = fn == "is_empty" ? "stdlib.collection.is_empty" : "stdlib.collection.non_empty"

      # ── OOF-COL1: arity ──────────────────────────────────────────────────────
      unless args.length == 1
        type_errors << oof("OOF-COL1",
          "#{qualified}: expected 1 argument (collection), got #{args.length}", node_name)
        return typed_expr("call", type_ir("Bool"), [], "fn" => qualified, "args" => [])
      end

      # ── Infer collection arg ──────────────────────────────────────────────────
      collection_typed = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      col_type_name    = type_name(collection_typed.fetch("resolved_type"))

      # ── OOF-COL2: first arg must be Collection or Unknown ─────────────────────
      unless col_type_name == "Collection" || col_type_name == "Unknown"
        type_errors << oof("OOF-COL2",
          "#{qualified}: first argument must be Collection[T], got #{col_type_name}", node_name)
        return typed_expr("call", type_ir("Bool"), collection_typed.fetch("deps", []),
                          "fn" => qualified, "args" => [collection_typed])
      end

      typed_expr("call", type_ir("Bool"), collection_typed.fetch("deps", []),
                 "fn" => qualified, "args" => [collection_typed])
    end

    # LANG-STDLIB-COLLECTION-RANGE-P2: stdlib.collection.range
    # range(start: Integer, stop: Integer) -> Collection[Integer]
    # Generates the exclusive interval [start, stop). Total: range(a, a) = []; range(b, a) where b>a = [].
    # OOF-COL1: arity != 2 (only diagnostic in v0 — arg types Unknown-permissive, not validated).
    def infer_range_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      qualified   = "stdlib.collection.range"
      result_type = collection_type_ir_from(type_ir("Integer"))

      # ── OOF-COL1: arity must be exactly 2 ───────────────────────────────────
      unless args.length == 2
        type_errors << oof("OOF-COL1",
          "#{qualified}: expected 2 arguments (start, stop), got #{args.length}", node_name)
        return typed_expr("call", result_type, [], "fn" => qualified, "args" => [])
      end

      # ── Infer both args — Unknown-permissive (no type validation in v0) ──────
      start_typed = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      stop_typed  = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
      deps        = (start_typed.fetch("deps", []) + stop_typed.fetch("deps", [])).uniq

      typed_expr("call", result_type, deps, "fn" => qualified, "args" => [start_typed, stop_typed])
    end

    # LAB-NUMERIC-DECIMAL-CONSTRUCT-P1: explicit Decimal constructor.
    #   decimal(value, scale) -> Decimal[scale]
    #   value : Integer (exact minor units), scale : Integer *literal*.
    # The scale must be a literal so Decimal[scale] is statically known (mirrors the
    # Decimal[N] annotation). OOF-TY0: arity != 2 or value not Integer. OOF-DM4:
    # non-literal / negative scale. On any error falls back to bare Decimal to avoid a
    # cascade. No implicit Float/Integer -> Decimal coercion. Mirrors the Rust TC arm.
    # The emitted fn stays the bare "decimal" (parity with the Rust SemanticIR; the VM
    # accepts both "decimal" and "stdlib.decimal.decimal").
    def infer_decimal_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      scale = nil

      if args.length != 2
        type_errors << oof("OOF-TY0",
          "stdlib.decimal.decimal: expected 2 arguments (value, scale), got #{args.length}", node_name)
        typed_args = args.map { |a| infer_expr(a, symbol_types, type_errors, type_warnings, node_name) }
        deps = typed_args.flat_map { |a| a.fetch("deps", []) }.uniq
        return typed_expr("call", type_ir("Decimal"), deps, "fn" => "decimal", "args" => typed_args)
      end

      value_typed = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      value_name  = type_name(value_typed.fetch("resolved_type"))
      unless value_name == "Integer" || value_name == "Unknown"
        type_errors << oof("OOF-TY0",
          "stdlib.decimal.decimal arg 1: expected Integer, got #{value_name}", node_name)
      end

      scale_node  = args[1]
      scale_typed = infer_expr(scale_node, symbol_types, type_errors, type_warnings, node_name)
      if scale_node.is_a?(Hash) && scale_node.fetch("kind", nil) == "literal" &&
         scale_node.fetch("type_tag", nil) == "Integer"
        scale_val = scale_node.fetch("value", nil)
        if scale_val.is_a?(Integer) && scale_val >= 0
          scale = scale_val
        else
          type_errors << oof("OOF-DM4",
            "stdlib.decimal.decimal: scale must be a non-negative Integer literal", node_name)
        end
      else
        type_errors << oof("OOF-DM4",
          "stdlib.decimal.decimal: scale must be an Integer literal", node_name)
      end

      result_type =
        if scale
          { "name" => "Decimal", "params" => [{ "name" => scale.to_s, "params" => [] }] }
        else
          type_ir("Decimal")
        end

      deps = (value_typed.fetch("deps", []) + scale_typed.fetch("deps", [])).uniq
      typed_expr("call", result_type, deps, "fn" => "decimal", "args" => [value_typed, scale_typed])
    end

    def infer_char_at_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      qualified = "stdlib.string.char_at"

      # OOF-TY0: arity must be exactly 2
      unless args.length == 2
        type_errors << oof("OOF-TY0",
          "#{qualified}: expected 2 argument(s), got #{args.length}", node_name)
        return typed_expr("call", type_ir("String"), [], "fn" => qualified, "args" => [])
      end

      # Infer and validate first arg — must be String or Unknown
      source_arg  = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      source_name = type_name(source_arg.fetch("resolved_type"))
      unless source_name == "Unknown" || source_name == "String"
        type_errors << oof("OOF-TY0",
          "#{qualified} arg 1: expected String, got #{source_name}", node_name)
      end

      # Infer and validate second arg — must be Integer or Unknown
      index_arg  = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
      index_name = type_name(index_arg.fetch("resolved_type"))
      unless index_name == "Unknown" || index_name == "Integer"
        type_errors << oof("OOF-TY0",
          "#{qualified} arg 2: expected Integer, got #{index_name}", node_name)
      end

      deps = (source_arg.fetch("deps", []) + index_arg.fetch("deps", [])).uniq
      typed_expr("call", type_ir("String"), deps,
                 "fn" => qualified, "args" => [source_arg, index_arg])
    end

    # LANG-STDLIB-STRING-SUBSTRING-P2: substring(String, Integer, Integer) -> String
    # (source, start, length) — byte-based, 0-based, length form not stop.
    # OOF-TY0: arity != 3 (early-return); arg1 not String/Unknown; arg2/arg3 not Integer/Unknown.
    # String returned on ALL paths including OOF. Unknown permissive all 3 positions.
    def infer_substring_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      qualified = "stdlib.string.substring"

      unless args.length == 3
        type_errors << oof("OOF-TY0",
          "#{qualified}: expected 3 argument(s), got #{args.length}", node_name)
        return typed_expr("call", type_ir("String"), [], "fn" => qualified, "args" => [])
      end

      source_arg  = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      source_name = type_name(source_arg.fetch("resolved_type"))
      unless source_name == "Unknown" || source_name == "String"
        type_errors << oof("OOF-TY0",
          "#{qualified} arg 1: expected String, got #{source_name}", node_name)
      end

      start_arg  = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
      start_name = type_name(start_arg.fetch("resolved_type"))
      unless start_name == "Unknown" || start_name == "Integer"
        type_errors << oof("OOF-TY0",
          "#{qualified} arg 2: expected Integer, got #{start_name}", node_name)
      end

      length_arg  = infer_expr(args[2], symbol_types, type_errors, type_warnings, node_name)
      length_name = type_name(length_arg.fetch("resolved_type"))
      unless length_name == "Unknown" || length_name == "Integer"
        type_errors << oof("OOF-TY0",
          "#{qualified} arg 3: expected Integer, got #{length_name}", node_name)
      end

      deps = (source_arg.fetch("deps", []) + start_arg.fetch("deps", []) + length_arg.fetch("deps", [])).uniq
      typed_expr("call", type_ir("String"), deps,
                 "fn" => qualified, "args" => [source_arg, start_arg, length_arg])
    end

    # LANG-STDLIB-COLLECTION-CONCAT-PROP-P3: stdlib.collection.concat
    # concat(Collection[T], Collection[T]) → Collection[T]
    # Source alias `concat` is shared with stdlib.text.concat — disambiguated here by first-arg type.
    # Collection or Unknown first arg → collection path.
    # Other concrete first arg → delegate to infer_text_call (stdlib.text.concat).
    # OOF-COL1: arity != 2  (collection path; early-return)
    # OOF-COL2: second arg not Collection/Unknown  (early-return)
    # OOF-COL7: element type mismatch — Collection[T] ++ Collection[U] where T ≠ U, both concrete
    # Unknown permissive on routing and on both element type positions.
    def infer_concat_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      qualified = "stdlib.collection.concat"

      # ── Routing: infer first arg to determine collection vs text path ─────────
      # args empty → cannot route; default to collection path for OOF-COL1
      if args.empty?
        type_errors << oof("OOF-COL1",
          "#{qualified}: expected 2 arguments, got 0", node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => qualified, "args" => [])
      end

      first_arg       = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      first_type_name = type_name(first_arg.fetch("resolved_type"))

      # Text/String/other concrete → delegate to stdlib.text.concat.
      # LANG-STRING-TEXT-ALIAS-P2: when both args are String, route to stdlib.string.concat → String.
      # String literals and String-typed refs both have type_name "String".
      unless first_type_name == "Collection" || first_type_name == "Unknown"
        if first_type_name == "String" && args.length == 2
          second_arg       = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
          second_type_name = type_name(second_arg.fetch("resolved_type"))
          if second_type_name == "String"
            deps = (first_arg.fetch("deps", []) + second_arg.fetch("deps", [])).uniq
            return typed_expr("call", type_ir("String"), deps,
                              "fn" => "stdlib.string.concat", "args" => [first_arg, second_arg])
          end
        end
        return infer_text_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      end

      # ── OOF-COL1: arity (collection path) ────────────────────────────────────
      unless args.length == 2
        type_errors << oof("OOF-COL1",
          "#{qualified}: expected 2 arguments, got #{args.length}", node_name)
        return typed_expr("call", type_ir("Unknown"), first_arg.fetch("deps", []),
                          "fn" => qualified, "args" => [first_arg])
      end

      # ── Infer second arg ──────────────────────────────────────────────────────
      second_arg       = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
      second_type_name = type_name(second_arg.fetch("resolved_type"))

      # ── OOF-COL2: second arg must be Collection or Unknown ────────────────────
      unless second_type_name == "Collection" || second_type_name == "Unknown"
        type_errors << oof("OOF-COL2",
          "#{qualified}: second argument must be Collection[T], got #{second_type_name}", node_name)
        all_deps = (first_arg.fetch("deps", []) + second_arg.fetch("deps", [])).uniq
        return typed_expr("call", type_ir("Unknown"), all_deps,
                          "fn" => qualified, "args" => [first_arg, second_arg])
      end

      # ── Element type extraction ───────────────────────────────────────────────
      elem1      = element_type_from_collection(first_arg.fetch("resolved_type"))
      elem2      = element_type_from_collection(second_arg.fetch("resolved_type"))
      elem1_name = type_name(elem1)
      elem2_name = type_name(elem2)

      # ── OOF-COL7: element type mismatch (first activation) ───────────────────
      # Only when both element types are concrete and different (Unknown permissive).
      unless elem1_name == "Unknown" || elem2_name == "Unknown" || elem1_name == elem2_name
        type_errors << oof("OOF-COL7",
          "#{qualified}: element type mismatch — first collection contains #{elem1_name}, second contains #{elem2_name}",
          node_name)
      end

      # Result type: prefer first arg's element type; fall back to second's if Unknown
      result_elem = elem1_name == "Unknown" ? elem2 : elem1
      all_deps = (first_arg.fetch("deps", []) + second_arg.fetch("deps", [])).uniq
      typed_expr("call", collection_type_ir_from(result_elem), all_deps,
                 "fn" => qualified, "args" => [first_arg, second_arg])
    end

    # Rule OR-ELSE: or_else(Option[V], V) → V
    # V extracted from Option params[0]. Unknown-compat: Unknown if not Option.
    # fn name in SemanticIR: "or_else" (no stdlib. prefix — v0 design).
    def infer_or_else(args, symbol_types, type_errors, type_warnings, node_name)
      unless args.length == 2
        type_errors << oof("OOF-TY0", "or_else requires 2 arguments (option, default)", node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => "or_else", "args" => [])
      end

      opt_arg     = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      default_arg = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)

      opt_type = opt_arg.fetch("resolved_type")
      inner_type = if type_name(opt_type) == "Option"
        params = opt_type.fetch("params", [])
        params.length >= 1 ? params[0] : type_ir("Unknown")
      else
        type_ir("Unknown")
      end

      deps = (opt_arg.fetch("deps", []) + default_arg.fetch("deps", [])).uniq
      typed_expr("call", inner_type, deps,
                 "fn" => "or_else", "args" => [opt_arg, default_arg])
    end

    # LANG-SUMTYPE-CONSTRUCT-MATCH-P3: sealed built-in constructors.
    # Lowers some/none/ok/err to a sealed `variant_construct` node (SIR marker
    # `sealed: true`), reusing the user-variant construct/emit machinery. Payload
    # labels are locked to value/error. Missing type params are recovered from the
    # expected-type hint (@sealed_output_hints) keyed on node_name; otherwise Unknown.
    def infer_sealed_construct(fn, args, symbol_types, type_errors, type_warnings, node_name)
      expected = sealed_arity(fn)
      unless args.length == expected
        type_errors << oof("OOF-TY0",
          "#{fn} requires #{expected} argument#{expected == 1 ? "" : "s"}", node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => fn, "args" => [])
      end

      typed_args = args.map { |a| infer_expr(a, symbol_types, type_errors, type_warnings, node_name) }
      deps = typed_args.flat_map { |a| a.fetch("deps", []) }.uniq
      hint = @sealed_output_hints&.fetch(node_name, nil)

      case fn
      when "some"
        inner = typed_args[0].fetch("resolved_type")
        build_sealed_construct("Some", "Option", { "value" => typed_args[0] }, option_type_ir(inner), deps)
      when "none"
        inner = hint_param(hint, "Option", 0)
        build_sealed_construct("None", "Option", {}, option_type_ir(inner), deps)
      when "ok"
        t = typed_args[0].fetch("resolved_type")
        e = hint_param(hint, "Result", 1)
        build_sealed_construct("Ok", "Result", { "value" => typed_args[0] }, result_type_ir(t, e), deps)
      when "err"
        e = typed_args[0].fetch("resolved_type")
        t = hint_param(hint, "Result", 0)
        build_sealed_construct("Err", "Result", { "error" => typed_args[0] }, result_type_ir(t, e), deps)
      end
    end

    def sealed_arity(fn) = fn == "none" ? 0 : 1

    # Recover param[idx] from an expected-type hint of the given family, else Unknown.
    def hint_param(hint, family, idx)
      return type_ir("Unknown") unless hint && type_name(hint) == family
      hint.fetch("params", []).fetch(idx, type_ir("Unknown"))
    end

    def build_sealed_construct(arm, variant, typed_fields, resolved_type, deps)
      typed_expr("variant_construct", resolved_type, deps,
                 "arm" => arm, "variant" => variant,
                 "typed_fields" => typed_fields, "sealed" => true)
    end

    # LANG-SUMTYPE-CONSTRUCT-MATCH-P3: unwrap_or(Result[T,E]|Option[T], default) -> T.
    # Mirrors or_else; extracts params[0] from Option/Result, else falls back to the
    # default argument's type. SIR call shape parallels or_else (both args carried).
    def infer_unwrap_or(args, symbol_types, type_errors, type_warnings, node_name)
      unless args.length == 2
        type_errors << oof("OOF-TY0", "unwrap_or requires 2 arguments (outcome, default)", node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => "unwrap_or", "args" => [])
      end

      outcome_arg = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      default_arg = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)

      out_type = outcome_arg.fetch("resolved_type")
      inner_type = if %w[Option Result].include?(type_name(out_type))
        params = out_type.fetch("params", [])
        params.length >= 1 ? params[0] : default_arg.fetch("resolved_type")
      else
        default_arg.fetch("resolved_type")
      end

      deps = (outcome_arg.fetch("deps", []) + default_arg.fetch("deps", [])).uniq
      typed_expr("call", inner_type, deps,
                 "fn" => "unwrap_or", "args" => [outcome_arg, default_arg])
    end

    # LANG-SUMTYPE-CONSTRUCT-MATCH-P3: and_then(Result[T,E], (T -> Result[U,E])) -> Result[U,E].
    # Fixed-error-family: the lambda param binds to T (the ok-type of the first arg);
    # the result keeps the input error type E and takes U from the lambda body's
    # Result[U,_]. A static call_contract may appear inside the lambda; no dynamic
    # callee dispatch is authorized here.
    def infer_and_then(args, symbol_types, type_errors, type_warnings, node_name)
      unless args.length == 2
        type_errors << oof("OOF-TY0", "and_then requires 2 arguments (result, lambda)", node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => "and_then", "args" => [])
      end

      result_arg = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      res_type   = result_arg.fetch("resolved_type")
      res_params = res_type.fetch("params", [])
      t_type     = res_params.fetch(0, type_ir("Unknown"))
      e_type     = res_params.fetch(1, type_ir("Unknown"))

      lambda_node = args[1]
      unless lambda_node.is_a?(Hash) && lambda_node.fetch("kind", nil) == "lambda"
        type_errors << oof("OOF-TY0",
          "and_then: second argument must be a lambda (T -> Result[U,E])", node_name)
        return typed_expr("call", type_ir("Unknown"), result_arg.fetch("deps", []),
                          "fn" => "and_then", "args" => [result_arg])
      end

      lambda_params = lambda_node.fetch("params", [])
      local_symbols = lambda_params.each_with_object(symbol_types.dup) { |p, acc| acc[p] = t_type }
      body_typed = infer_lambda_body(lambda_node.fetch("body"), local_symbols, type_errors, type_warnings, node_name)
      body_type  = body_typed.fetch("resolved_type")

      u_type = if type_name(body_type) == "Result"
        body_type.fetch("params", []).fetch(0, type_ir("Unknown"))
      else
        type_ir("Unknown")
      end

      deps = (result_arg.fetch("deps", []) + body_typed.fetch("deps", [])).uniq
      typed_expr("call", result_type_ir(u_type, e_type), deps,
                 "fn" => "and_then", "args" => [result_arg])
    end

    # array_literal: infers Collection[T] from the first non-Unknown element type.
    # Empty array: Collection[Unknown]. Required for map_from_pairs pair arrays.
    def infer_array_literal(expr, symbol_types, type_errors, type_warnings, node_name)
      items = expr.fetch("items", [])
      if items.empty?
        return typed_expr("array_literal", collection_type_ir_from(type_ir("Unknown")), [], "items" => [])
      end

      typed_items = items.map { |item| infer_expr(item, symbol_types, type_errors, type_warnings, node_name) }
      elem_type   = typed_items.map { |ti| ti.fetch("resolved_type") }
                               .find { |t| type_name(t) != "Unknown" } || type_ir("Unknown")
      deps = typed_items.flat_map { |ti| ti.fetch("deps", []) }.uniq
      typed_expr("array_literal", collection_type_ir_from(elem_type), deps, "items" => typed_items)
    end

    # record_literal: resolves to named Record type via @output_type_hints if available.
    # Validates field presence, no extra fields, and type_name compatibility.
    # Falls back to Unknown if no hint or on field mismatch.
    def infer_record_literal(expr, symbol_types, type_errors, type_warnings, node_name)
      fields = expr.fetch("fields", {})
      hint_type = @output_type_hints&.fetch(node_name, nil)
      expected_fields_for_hint =
        if hint_type && type_name(hint_type) != "Unknown"
          @type_shapes.fetch(type_name(hint_type), {})
        else
          {}
        end

      typed_fields = fields.each_with_object({}) do |(fname, val_expr), acc|
        field_node_name = record_literal_field_node_name(node_name, fname)
        expected_field_type = expected_fields_for_hint[fname]
        # LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3: a nested record literal in a
        # declared-optional Option[Rec] field is hinted with the INNER record
        # type; the validation loop below wraps the typed result in Some.
        if optional_shape_field?(expected_field_type)
          inner = optional_inner_type(expected_field_type)
          expected_field_type = inner if @type_shapes.key?(type_name(inner))
        end

        if val_expr.is_a?(Hash) &&
           val_expr.fetch("kind", nil) == "record_literal" &&
           expected_field_type &&
           @type_shapes.key?(type_name(expected_field_type))
          had_previous_hint = @output_type_hints.key?(field_node_name)
          previous_hint = @output_type_hints[field_node_name]
          @output_type_hints[field_node_name] = expected_field_type
          begin
            acc[fname] = infer_expr(val_expr, symbol_types, type_errors, type_warnings, field_node_name)
          ensure
            if had_previous_hint
              @output_type_hints[field_node_name] = previous_hint
            else
              @output_type_hints.delete(field_node_name)
            end
          end
        else
          acc[fname] = infer_expr(val_expr, symbol_types, type_errors, type_warnings, field_node_name)
        end
      end
      deps = typed_fields.values.flat_map { |tf| tf.fetch("deps", []) }.uniq

      if hint_type && type_name(hint_type) != "Unknown"
        type_name_str   = type_name(hint_type)
        expected_fields = expected_fields_for_hint
        field_errors    = []

        expected_fields.each do |fname, expected_type|
          if typed_fields.key?(fname)
            actual_type = typed_fields[fname].fetch("resolved_type")
            # LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3 (flag present only when the
            # gate is ON): present Option[T] → passthrough; present raw T →
            # auto-wrap to Some (TC-synthesized option_construct); Unknown stays
            # permissive (house rule); anything else falls through to the
            # existing OOF-TY0 (fail-closed, no new code).
            if optional_shape_field?(expected_type)
              inner_type = optional_inner_type(expected_type)
              actual_name = type_name(actual_type)
              if actual_name == "Option" || actual_name == "Unknown"
                # passthrough as-is
              elsif actual_name == type_name(inner_type) ||
                    structurally_assignable?(actual_type, inner_type) ||
                    empty_collection_assignable?(actual_type, inner_type)
                typed_fields[fname] = option_some_node(typed_fields[fname], inner_type)
              else
                field_errors << oof(
                  "OOF-TY0",
                  "record literal field '#{fname}': expected #{type_name(expected_type)}, " \
                  "got #{type_name(actual_type)}",
                  node_name
                )
              end
            else
              unless type_name(actual_type) == type_name(expected_type) ||
                     type_name(actual_type) == "Unknown"
                field_errors << oof(
                  "OOF-TY0",
                  "record literal field '#{fname}': expected #{type_name(expected_type)}, " \
                  "got #{type_name(actual_type)}",
                  node_name
                )
              end
            end
          elsif optional_shape_field?(expected_type)
            # P3: omitted declared-optional field → present-with-None (rectangular).
            typed_fields[fname] = option_none_node(optional_inner_type(expected_type))
          else
            field_errors << oof("OOF-TY0", "record literal missing required field: #{fname}", node_name)
          end
        end

        typed_fields.each_key do |fname|
          unless expected_fields.key?(fname)
            field_errors << oof("OOF-TY0", "record literal has unexpected field: #{fname}", node_name)
          end
        end

        if field_errors.empty?
          return typed_expr("record_literal", hint_type, deps, "fields" => typed_fields)
        else
          type_errors.concat(field_errors)
          return typed_expr("record_literal", type_ir("Unknown"), deps, "fields" => typed_fields)
        end
      end

      # P3: structural field-set matching against @type_shapes when no hint was available.
      # Finds all type shapes whose field names exactly equal the literal's field names and
      # whose field types are compatible (Unknown literal values are permissive).
      literal_field_names = typed_fields.keys.sort
      candidates = @type_shapes.select do |tn, shape_fields|
        if @optional_fields && shape_fields.any? { |_, t| optional_shape_field?(t) }
          # LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3 (gate ON, shape has optional
          # fields): the literal may omit ONLY declared-optional fields —
          # required ⊆ literal ⊆ all — and present optional values match
          # against inner T or Option[T].
          optional_aware_structural_match?(shape_fields, typed_fields, literal_field_names)
        else
          shape_fields.keys.sort == literal_field_names &&
            shape_fields.all? do |fname, exp_type|
              act_type = typed_fields[fname].fetch("resolved_type")
              type_name(act_type) == "Unknown" ||
                structurally_assignable?(act_type, exp_type) ||
                empty_collection_assignable?(act_type, exp_type)
            end
        end
      end

      if candidates.length == 1
        matched_name, matched_fields = candidates.first
        # P3: rectangular lowering for the structurally-matched shape too —
        # inject None for omitted optional fields, auto-wrap present raw-T values.
        apply_optional_construction!(typed_fields, matched_fields) if @optional_fields
        return typed_expr("record_literal", type_ir(matched_name), deps, "fields" => typed_fields)
      elsif candidates.length > 1
        type_errors << oof(
          "OOF-TY0",
          "Ambiguous record literal type: fields {#{literal_field_names.join(", ")}} match #{candidates.keys.join(", ")}",
          node_name
        )
      end

      typed_expr("record_literal", type_ir("Unknown"), deps, "fields" => typed_fields)
    end

    # LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3: structural candidate matching when the
    # shape declares optional fields (gate ON only — flags never appear otherwise).
    # required ⊆ literal ⊆ all; present optional values match inner T or Option[T].
    def optional_aware_structural_match?(shape_fields, typed_fields, literal_field_names)
      required = shape_fields.reject { |_, t| optional_shape_field?(t) }.keys.sort
      all_names = shape_fields.keys.sort
      return false unless (required - literal_field_names).empty? &&
                          (literal_field_names - all_names).empty?
      shape_fields.all? do |fname, exp_type|
        next true unless typed_fields.key?(fname)
        act_type = typed_fields[fname].fetch("resolved_type")
        next true if type_name(act_type) == "Unknown"
        if optional_shape_field?(exp_type)
          inner = optional_inner_type(exp_type)
          type_name(act_type) == "Option" ||
            structurally_assignable?(act_type, inner) ||
            empty_collection_assignable?(act_type, inner)
        else
          structurally_assignable?(act_type, exp_type) ||
            empty_collection_assignable?(act_type, exp_type)
        end
      end
    end

    # LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3: rectangular construction lowering for
    # an already-matched shape — omitted optional fields become option_construct
    # `none`, present raw-T values are wrapped in option_construct `some`
    # (present Option/Unknown values pass through). Mutates typed_fields in place.
    def apply_optional_construction!(typed_fields, shape_fields)
      shape_fields.each do |fname, exp_type|
        next unless optional_shape_field?(exp_type)
        inner = optional_inner_type(exp_type)
        if typed_fields.key?(fname)
          actual_name = type_name(typed_fields[fname].fetch("resolved_type"))
          next if actual_name == "Option" || actual_name == "Unknown"
          typed_fields[fname] = option_some_node(typed_fields[fname], inner)
        else
          typed_fields[fname] = option_none_node(inner)
        end
      end
    end

    # PROP-044 P5: infer a variant_construct expression.
    # Resolves the variant by searching @variant_shapes for the arm name.
    # Validates all supplied fields against the arm's declared field types.
    # Returns type_ir(variant_name) on success; type_ir("Unknown") with OOF-KIND2 on failure.
    def infer_variant_construct(expr, symbol_types, type_errors, type_warnings, node_name)
      arm_name = expr.fetch("arm")
      fields   = expr.fetch("fields", {})

      variant_name = find_variant_for_arm(arm_name)
      if variant_name.nil?
        type_errors << oof("OOF-KIND2",
          "variant_construct arm '#{arm_name}' is not declared in any variant",
          node_name)
        return typed_expr("variant_construct", type_ir("Unknown"), [],
                          "arm" => arm_name, "variant" => nil, "typed_fields" => {})
      end

      arm_fields   = @variant_shapes[variant_name][arm_name]
      typed_fields = {}
      field_deps   = []

      fields.each do |fname, fexpr|
        typed_f = infer_expr(fexpr, symbol_types, type_errors, type_warnings, node_name)
        if arm_fields.key?(fname)
          expected = arm_fields[fname]
          actual   = typed_f.fetch("resolved_type")
          unless type_name(actual) == type_name(expected) || type_name(actual) == "Unknown"
            type_errors << oof("OOF-KIND2",
              "#{variant_name}::#{arm_name} field '#{fname}': " \
              "expected #{type_name(expected)}, got #{type_name(actual)}",
              node_name)
          end
        else
          type_errors << oof("OOF-KIND2",
            "field '#{fname}' is not declared in #{variant_name}::#{arm_name}",
            node_name)
        end
        typed_fields[fname] = typed_f
        field_deps.concat(typed_f.fetch("deps", []))
      end

      arm_fields.each_key do |required|
        unless fields.key?(required)
          type_errors << oof("OOF-KIND2",
            "#{variant_name}::#{arm_name} is missing required field '#{required}'",
            node_name)
        end
      end

      typed_expr("variant_construct", type_ir(variant_name), field_deps.uniq,
                 "arm" => arm_name, "variant" => variant_name, "typed_fields" => typed_fields)
    end

    # PROP-044 P5: infer a match_expr.
    # Full mode: subject is a known variant → arm narrowing + exhaustiveness.
    # Degraded mode: subject is Unknown (prior error) or non-variant type → walk arms, no narrowing.
    def infer_match_expr(expr, symbol_types, type_errors, type_warnings, node_name)
      subject_node = infer_expr(expr.fetch("subject"), symbol_types,
                                type_errors, type_warnings, node_name)
      subject_type = type_name(subject_node.fetch("resolved_type"))

      # Non-variant subject — OOF-KIND4 (suppress if already Unknown from prior error)
      unless variant_type?(subject_type) || subject_type == "Unknown"
        type_errors << oof("OOF-KIND4",
          "match subject has type '#{subject_type}' which is not a variant type",
          node_name)
        return infer_match_expr_degraded(expr, subject_node, symbol_types,
                                        type_errors, type_warnings, node_name)
      end

      # Unknown subject: degraded mode without OOF-KIND4 (upstream error already explains it)
      unless variant_type?(subject_type)
        return infer_match_expr_degraded(expr, subject_node, symbol_types,
                                        type_errors, type_warnings, node_name)
      end

      declared_arms = variant_arms(subject_type)
      sealed        = sealed_builtin?(subject_type)  # LANG-SUMTYPE-CONSTRUCT-MATCH-P3
      subject_rt    = subject_node.fetch("resolved_type")
      covered_arms  = {}
      has_wildcard  = false
      arm_types     = []
      typed_arms    = []

      expr.fetch("arms").each_with_index do |arm, idx|
        pattern = arm.fetch("pattern")

        if pattern.fetch("wildcard", false)
          has_wildcard = true
          typed_body   = infer_expr(arm.fetch("body"), symbol_types,
                                    type_errors, type_warnings, node_name)
          arm_types  << typed_body.fetch("resolved_type")
          typed_arms << { "pattern" => pattern, "body" => typed_body }
          next
        end

        arm_name = pattern.fetch("arm")
        bindings = pattern.fetch("bindings", [])

        # OOF-KIND3: already covered (unreachable arm)
        if covered_arms.key?(arm_name)
          type_errors << oof("OOF-KIND3",
            "arm '#{arm_name}' is unreachable — already covered at position #{covered_arms[arm_name]}",
            node_name)
          next
        end

        covered_arms[arm_name] = idx

        # OOF-KIND2: arm not declared in this variant
        unless declared_arms.key?(arm_name)
          type_errors << oof("OOF-KIND2",
            "arm '#{arm_name}' is not declared in variant '#{subject_type}'",
            node_name)
          typed_body = infer_expr(arm.fetch("body"), symbol_types,
                                  type_errors, type_warnings, node_name)
          arm_types  << typed_body.fetch("resolved_type")
          typed_arms << { "pattern" => pattern, "body" => typed_body }
          next
        end

        arm_field_shapes = declared_arms[arm_name]
        # Sealed built-ins substitute the concrete payload type from the subject's
        # params; user variants use their declared field types directly.
        bind_types = sealed ? sealed_arm_field_types(subject_rt, arm_name) : arm_field_shapes
        arm_bindings = {}
        bindings.each do |binding|
          if arm_field_shapes.key?(binding)
            arm_bindings[binding] = bind_types.fetch(binding, type_ir("Unknown"))
          else
            type_errors << oof("OOF-KIND2",
              "binding '#{binding}' is not a field of #{subject_type}::#{arm_name}",
              node_name)
            arm_bindings[binding] = type_ir("Unknown")
          end
        end

        arm_scope  = symbol_types.merge(arm_bindings)
        typed_body = infer_expr(arm.fetch("body"), arm_scope,
                                type_errors, type_warnings, node_name)
        arm_types  << typed_body.fetch("resolved_type")
        typed_arms << { "pattern" => pattern, "body" => typed_body }
      end

      # OOF-KIND1: non-exhaustive match (missing arms, no wildcard)
      uncovered = declared_arms.keys - covered_arms.keys
      if uncovered.any? && !has_wildcard
        type_errors << oof("OOF-KIND1",
          "match on '#{subject_type}' is non-exhaustive — " \
          "missing arms: #{uncovered.sort.join(", ")}",
          node_name)
      end

      result_type  = unify_match_arm_types(arm_types, subject_type, node_name, type_errors)
      subject_deps = subject_node.fetch("deps", [])
      arm_deps     = typed_arms.flat_map { |a| a.fetch("body", {}).fetch("deps", []) }

      match_extra = {
        "subject"      => subject_node,
        "subject_type" => subject_type,
        "arms"         => typed_arms,
        "exhaustive"   => uncovered.empty? || has_wildcard,
        "has_wildcard" => has_wildcard,
      }
      match_extra["sealed"] = true if sealed  # LANG-SUMTYPE-CONSTRUCT-MATCH-P3
      typed_expr("match_expr", result_type, (subject_deps + arm_deps).uniq, match_extra)
    end

    def infer_match_expr_degraded(expr, subject_node, symbol_types, type_errors, type_warnings, node_name)
      expr.fetch("arms").each do |arm|
        infer_expr(arm.fetch("body"), symbol_types, type_errors, type_warnings, node_name)
      end
      typed_expr("match_expr", type_ir("Unknown"), subject_node.fetch("deps", []),
                 "subject" => subject_node, "arms" => [], "exhaustive" => false,
                 "has_wildcard" => false)
    end

    def infer_unary_op(expr, symbol_types, type_errors, type_warnings, node_name)
      op      = expr.fetch("op")
      operand = infer_expr(expr.fetch("operand"), symbol_types, type_errors, type_warnings, node_name)
      op_type = type_name(operand.fetch("resolved_type"))

      case op
      when "!"
        unless op_type == "Unknown" || op_type == "Bool"
          type_errors << oof("OOF-TY0",
            "stdlib.primitive.not: expected Bool operand, got #{op_type}", node_name)
        end
        typed_expr("call", type_ir("Bool"), operand.fetch("deps"),
                   "fn" => "stdlib.primitive.not", "args" => [operand])
      when "-"
        unless op_type == "Unknown" || op_type == "Integer"
          type_errors << oof("OOF-TY0",
            "stdlib.integer.neg: expected Integer operand, got #{op_type}", node_name)
        end
        typed_expr("call", type_ir("Integer"), operand.fetch("deps"),
                   "fn" => "stdlib.integer.neg", "args" => [operand])
      else
        type_errors << oof("OOF-TY0", "Unsupported unary operator: #{op}", node_name)
        typed_expr("call", type_ir("Unknown"), operand.fetch("deps"),
                   "fn" => "stdlib.unsupported.#{op}", "args" => [operand])
      end
    end

    def unify_match_arm_types(arm_types, subject_type, node_name, type_errors)
      return type_ir("Unknown") if arm_types.empty?

      # Top-level Unknown arms contribute nothing to the join (legacy behavior).
      present = arm_types.reject { |t| type_name(t) == "Unknown" }
      return type_ir("Unknown") if present.empty?

      names = present.map { |t| type_name(t) }.uniq
      if names.length > 1
        type_errors << oof("OOF-KIND5",
          "match on '#{subject_type}' has divergent arm result types: #{names.sort.join(", ")}",
          node_name)
        return type_ir("Unknown")
      end

      # LANG-MATCH-ARM-PARAM-UNIFICATION-P2 (route A): preserve type params when all
      # arms share the parametric family, via a position-wise structural join.
      # PURE precision widening — every case that previously dropped params still
      # returns the byte-identical legacy `type_ir(name)`; params are preserved only
      # when the join yields a non-empty, fully-resolved (not Unknown-bearing) result.
      name   = names.first
      joined = present.reduce { |acc, t| join_match_param_types(acc, t) }
      if joined && !joined.fetch("params", []).empty? && !unknown_or_unknown_bearing?(joined)
        return joined
      end
      type_ir(name)
    end

    # Position-wise structural join of two arm result types. `Unknown` is the join
    # bottom: join(Unknown, X) = X. Identical structures are preserved as-is (keeps
    # any extra keys, e.g. OLAPPoint dims). Arity or concrete-name conflict at any
    # depth returns nil ⇒ the caller degrades to the legacy bare family result.
    # No diagnostic is emitted here (P2 reserves OOF-KIND7 for a future strictness
    # card; OOF-KIND6 is already taken by PROP-044-P9 reserved-field-name checks).
    def join_match_param_types(a, b)
      return nil if a.nil? || b.nil?
      na = type_name(a)
      nb = type_name(b)
      return b if na == "Unknown"
      return a if nb == "Unknown"
      return nil if na != nb
      return a if a == b   # identical — preserve all keys, zero change

      pa = a.fetch("params", [])
      pb = b.fetch("params", [])
      return nil if pa.length != pb.length

      joined_params = []
      pa.zip(pb).each do |x, y|
        jp = join_match_param_types(x, y)
        return nil if jp.nil?
        joined_params << jp
      end
      { "name" => na, "params" => joined_params }
    end

    # check_map_annotation: validates a single type_annotation for Map constraint violations.
    # OOF-MAP1: non-String key (exempts Unknown key).
    # OOF-MAP2: Any value — permanently closed.
    # OOF-MAP3: Unknown value in output declarations only.
    def check_map_annotation(annotation, node_name, decl_kind, errors)
      return unless annotation.is_a?(Hash) && annotation.fetch("name", nil) == "Map"

      params    = annotation.fetch("params", [])
      key_param = params[0]
      val_param = params[1]
      key_name  = param_type_name(key_param)
      val_name  = param_type_name(val_param)

      if key_name && key_name != "String" && key_name != "Unknown"
        errors << oof(
          "OOF-MAP1",
          "Map key type in v0 must be String; " \
          "Map[K,V] where K = '#{key_name}' requires v1 authorization; " \
          "use Map[String,V] or a named Record for known key schemas",
          node_name
        )
      end

      if val_name == "Any"
        errors << oof(
          "OOF-MAP2",
          "Map value type 'Any' is permanently closed at contract boundaries; " \
          "use a homogeneous type V or a named Record",
          node_name
        )
      end

      if decl_kind == "output" && val_name == "Unknown"
        errors << oof(
          "OOF-MAP3",
          "Map value type 'Unknown' is a compiler uncertainty marker and must not " \
          "appear in user-declared output type annotations",
          node_name
        )
      end
    end

    # Extract the type name from a param entry (Hash or String).
    def param_type_name(param)
      return nil if param.nil?
      param.is_a?(Hash) ? param.fetch("name", nil) : param.to_s
    end

    # Map[K,V] type IR. K and V may be Hash type_ir or String type name.
    def map_type_ir(key, value)
      key_ir = key.is_a?(Hash) ? key : { "name" => key.to_s, "params" => [] }
      val_ir = value.is_a?(Hash) ? value : { "name" => value.to_s, "params" => [] }
      { "name" => "Map", "params" => [key_ir, val_ir] }
    end

    # Option[V] type IR. V may be Hash type_ir or String type name.
    def option_type_ir(inner)
      inner_ir = inner.is_a?(Hash) ? inner : type_ir(inner.to_s)
      { "name" => "Option", "params" => [inner_ir] }
    end

    # Result[T,E] type IR. LANG-SUMTYPE-CONSTRUCT-MATCH-P3.
    def result_type_ir(ok_type, err_type)
      ok_ir  = ok_type.is_a?(Hash)  ? ok_type  : type_ir(ok_type.to_s)
      err_ir = err_type.is_a?(Hash) ? err_type : type_ir(err_type.to_s)
      { "name" => "Result", "params" => [ok_ir, err_ir] }
    end

    # Collection[V] type IR. elem_type_ir may be Hash type_ir or String type name.
    def collection_type_ir_from(elem_type_ir)
      { "name" => "Collection",
        "params" => [elem_type_ir.is_a?(Hash) ? elem_type_ir : type_ir(elem_type_ir.to_s)] }
    end

    # ── End PROP-043 ─────────────────────────────────────────────────────────────

    # Produce typed body array for SemanticIR lowering.
    # Returns array of hashes with kind "lead" or "compute".
    def typed_loop_body(loop_decl, _outer_symbols, _item_name, _item_type)
      loop_decl.fetch("body", []).filter_map do |b|
        case b.fetch("kind", "")
        when "lead"
          {
            "kind"            => "lead",
            "name"            => b.fetch("name"),
            "type_annotation" => b.fetch("type_annotation", "Unknown"),
            "initial"         => b.fetch("initial", nil)
          }
        when "compute"
          {
            "kind" => "compute",
            "name" => b.fetch("name"),
            "expr" => b.fetch("expr", nil)
          }
        end
      end
    end
  end

  Typechecker = TypeChecker
end
