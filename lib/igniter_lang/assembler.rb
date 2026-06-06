# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "pathname"

module IgniterLang
  class AssemblyRefused < StandardError; end

  class Assembler
    ROOT = Pathname.new(File.expand_path("../..", __dir__))
    DEFAULT_GOLDEN_DIR = ROOT / "experiments/source_to_semanticir_fixture/golden"
    DEFAULT_OUT_DIR = ROOT / "experiments/igapp_assembler_proof/out"

    # PROP-036: compiler_profile_id source contract constants.
    # Used by validate_compiler_profile_source! only.
    PROFILE_SOURCE_KIND       = "compiler_profile_id_source"
    PROFILE_SOURCE_NAMESPACE  = "compiler_profile_unified"
    PROFILE_SOURCE_ID_PATTERN = /\Acompiler_profile_unified\/sha256:[0-9a-f]{24,}\z/
    PROFILE_SOURCE_SLOT_ORDER = %w[
      core oof_registry fragment_registry escape_boundary contract_modifiers
      temporal stream olap invariant assumptions evidence_observation pipeline
    ].freeze

    module Canonical
      module_function

      def normalize(value)
        case value
        when Hash
          value.keys.sort_by(&:to_s).each_with_object({}) do |key, out|
            out[key.to_s] = normalize(value[key])
          end
        when Array
          value.map { |item| normalize(item) }
        when Symbol
          value.to_s
        else
          value
        end
      end

      def json(value)
        JSON.pretty_generate(normalize(value)) + "\n"
      end

      def hash(value)
        "sha256:#{Digest::SHA256.hexdigest(JSON.generate(normalize(value)))}"
      end

      def short_hash(value)
        hash(value).split(":").last[0, 16]
      end
    end

    def initialize(golden_dir: DEFAULT_GOLDEN_DIR, out_dir: DEFAULT_OUT_DIR)
      @golden_dir = Pathname.new(golden_dir)
      @out_dir = Pathname.new(out_dir)
    end

    def assemble_case(case_name, compiler_profile_source: nil)
      report = read_json(@golden_dir / "#{case_name}.compilation_report.json")
      refuse!(case_name, "pass_result=#{report.fetch("pass_result")}") unless report.fetch("pass_result") == "ok"
      refuse!(case_name, "semantic_ir_ref missing") unless report.fetch("semantic_ir_ref").is_a?(String)

      semantic_ir = read_json(@golden_dir / "#{case_name}.semantic_ir.json")
      validate_refs!(case_name, report, semantic_ir)
      validate_semantic_ir!(case_name, semantic_ir)

      artifact = build_artifact(case_name, report, semantic_ir, compiler_profile_source: compiler_profile_source)
      write_artifact(case_name, artifact)
      artifact_summary(case_name, artifact)
    end

    def assemble_artifacts(case_name:, report:, semantic_ir:, target_dir:, compiler_profile_source: nil)
      refuse!(case_name, "pass_result=#{report.fetch("pass_result")}") unless report.fetch("pass_result") == "ok"
      refuse!(case_name, "semantic_ir_ref missing") unless report.fetch("semantic_ir_ref").is_a?(String)
      validate_refs!(case_name, report, semantic_ir)
      validate_semantic_ir!(case_name, semantic_ir)

      artifact = build_artifact(case_name, report, semantic_ir, compiler_profile_source: compiler_profile_source)
      target = Pathname.new(target_dir)
      write_artifact_to(target, artifact)
      artifact_summary_for_target(case_name, artifact, target)
    end

    def refuse_case(case_name)
      report = read_json(@golden_dir / "#{case_name}.compilation_report.json")
      assemble_case(case_name)
      raise "expected #{case_name} to refuse, but it assembled"
    rescue AssemblyRefused => e
      target = @out_dir / "#{case_name}.igapp"
      {
        "case" => case_name,
        "status" => "refused",
        "pass_result" => report.fetch("pass_result"),
        "reason" => e.message,
        "wrote_igapp" => target.exist?
      }
    end

    private

    def read_json(path)
      JSON.parse(File.read(path))
    end

    def refuse!(case_name, reason)
      raise AssemblyRefused, "#{case_name}: #{reason}"
    end

    # PROP-036: validate a compiler_profile_id_source object before assembler use.
    # Raises AssemblyRefused with compiler_profile_source.* reason text on any
    # invalid input. Must not emit loader/report status values.
    def validate_compiler_profile_source!(case_name, source)
      unless source.is_a?(Hash)
        refuse!(case_name, "compiler_profile_source.malformed: source must be a Hash")
      end

      kind = source["kind"]
      unless kind == PROFILE_SOURCE_KIND
        refuse!(case_name, "compiler_profile_source.wrong_kind: #{kind.inspect}")
      end

      status = source["status"]
      unless status == "finalized"
        refuse!(case_name, "compiler_profile_source.unfinalized: status=#{status.inspect}")
      end

      namespace = source["profile_namespace"]
      unless namespace == PROFILE_SOURCE_NAMESPACE
        refuse!(case_name, "compiler_profile_source.unsupported_namespace: #{namespace.inspect}")
      end

      cid = source["compiler_profile_id"]
      unless cid.is_a?(String) && cid.match?(PROFILE_SOURCE_ID_PATTERN)
        refuse!(case_name, "compiler_profile_source.malformed_id: #{cid.inspect}")
      end

      slot_order = source["slot_order"]
      unless slot_order == PROFILE_SOURCE_SLOT_ORDER
        refuse!(case_name, "compiler_profile_source.slot_order_mismatch")
      end

      # Reconstruct finalization payload and verify digest + id consistency.
      payload = {
        "profile_namespace"  => source["profile_namespace"],
        "format_version"     => source["format_version"],
        "descriptor_digest"  => source["descriptor_digest"],
        "profile_kind"       => source["profile_kind"],
        "slot_order"         => source["slot_order"],
        "slot_assignments"   => source.fetch("slot_assignments", {})
      }
      payload_hex            = Digest::SHA256.hexdigest(JSON.generate(Canonical.normalize(payload)))
      expected_payload_digest = "sha256:#{payload_hex}"
      expected_profile_id    = "#{PROFILE_SOURCE_NAMESPACE}/sha256:#{payload_hex[0, 24]}"

      unless source["finalization_payload_digest"] == expected_payload_digest
        refuse!(case_name, "compiler_profile_source.id_digest_mismatch: finalization_payload_digest")
      end
      unless cid == expected_profile_id
        refuse!(case_name, "compiler_profile_source.id_digest_mismatch: compiler_profile_id")
      end

      if source["runtime_authority_granted"] == true
        refuse!(case_name, "compiler_profile_source.runtime_authority_forbidden")
      end
      if source["dispatch_migration_authorized"] == true
        refuse!(case_name, "compiler_profile_source.dispatch_migration_forbidden")
      end
    end

    def validate_refs!(case_name, report, semantic_ir)
      refuse!(case_name, "SemanticIR kind=#{semantic_ir.fetch("kind", nil)}") unless semantic_ir.fetch("kind") == "semantic_ir_program"
      refuse!(case_name, "semantic_ir_ref mismatch") unless report.fetch("semantic_ir_ref") == semantic_ir.fetch("program_id")
      return if semantic_ir.fetch("compilation_report_ref") == report.fetch("program_id")

      refuse!(case_name, "compilation_report_ref mismatch")
    end

    def validate_semantic_ir!(case_name, semantic_ir)
      semantic_ir.fetch("contracts").each do |contract|
        refuse!(case_name, "OOF contract emitted: #{contract.fetch("contract_name")}") if contract.fetch("fragment_class") == "oof"
      end

      return unless JSON.generate(semantic_ir).include?("stdlib.numeric.")

      refuse!(case_name, "unresolved stdlib.numeric operator in SemanticIR")
    end

    def build_artifact(case_name, report, semantic_ir, compiler_profile_source: nil)
      # PROP-036: validate source object and extract id before building hash material.
      # validate_compiler_profile_source! raises AssemblyRefused on any invalid input.
      compiler_profile_id = if compiler_profile_source
        validate_compiler_profile_source!(case_name, compiler_profile_source)
        compiler_profile_source.fetch("compiler_profile_id")
      end

      contracts = semantic_ir.fetch("contracts").map { |contract| contract_file(contract) }
      contract_ids = contracts.map { |contract| contract.fetch("contract_id") }.sort
      fragment_classes = contracts.map { |contract| contract.fetch("fragment_class") }.uniq
      fragment_class = fragment_classes.length == 1 ? fragment_classes.first : "mixed"
      requirements = requirements_for(semantic_ir)
      classified_ast = classified_ast_for(report, semantic_ir, contract_ids, fragment_class)
      diagnostics = { "diagnostics" => report.fetch("diagnostics") }
      compatibility_metadata = compatibility_metadata_for(report, semantic_ir)

      artifact_material = {
        "semantic_ir_program" => semantic_ir,
        "contracts" => contracts,
        "compilation_report" => report,
        "requirements" => requirements,
        "diagnostics" => diagnostics,
        "classified_ast" => classified_ast,
        "compatibility_metadata" => compatibility_metadata
      }
      # PROP-036: inject compiler_profile_id into hash material BEFORE artifact_hash
      # is computed. Adding it after Canonical.hash is called is forbidden.
      artifact_material["compiler_profile_id"] = compiler_profile_id if compiler_profile_id

      artifact_hash = Canonical.hash(artifact_material)
      contracts = contracts.map { |contract| contract.merge("artifact_hash" => artifact_hash) }
      fragment_summary = fragment_summary_for(contracts)
      contract_index = contract_index_for(contracts)

      manifest = {
        "kind" => "igapp_manifest",
        "format_version" => "0.1.0",
        "format" => "igapp_dir",
        "program_id" => semantic_ir.fetch("program_id"),
        "artifact_hash" => artifact_hash,
        "language_version" => semantic_ir.fetch("format_version"),
        "grammar_version" => semantic_ir.fetch("grammar_version"),
        "schema_version" => "0.1.0",
        "compiled_at" => "2026-05-06T00:00:00Z",
        "assembler" => "igapp-assembler-proof-stage1-v0",
        "semantic_ir_ref" => report.fetch("semantic_ir_ref"),
        "compilation_report_ref" => semantic_ir.fetch("compilation_report_ref"),
        "source_hash" => semantic_ir.fetch("source_hash"),
        "source_path" => semantic_ir.fetch("source_path"),
        "contracts" => contract_ids,
        "contract_refs" => semantic_ir.fetch("contracts").to_h do |contract|
          [contract.fetch("contract_name"), contract.fetch("contract_ref")]
        end,
        "fragment_class" => fragment_class,
        "fragment_summary" => fragment_summary,
        "contract_index" => contract_index,
        "schema_descriptor" => { "trait_bounds" => [], "migrations" => [] },
        "warnings" => [],
        "diagnostics" => report.fetch("diagnostics")
      }
      # PROP-036: top-level manifest field; only present when a valid source is supplied.
      manifest["compiler_profile_id"] = compiler_profile_id if compiler_profile_id

      {
        "case" => case_name,
        "manifest" => manifest,
        "semantic_ir_program" => semantic_ir,
        "contracts" => contracts,
        "compilation_report" => report,
        "requirements" => requirements,
        "diagnostics" => diagnostics,
        "classified_ast" => classified_ast,
        "projections" => { "projections" => [] },
        "compatibility_metadata" => compatibility_metadata
      }
    end

    def contract_file(contract_ir)
      contract_id = contract_ir.fetch("contract_name")
      input_ports = ports(contract_ir.fetch("inputs"))
      output_ports = ports(contract_ir.fetch("outputs"))
      semantic_nodes = contract_ir.fetch("nodes")
      compute_nodes = semantic_nodes.filter_map do |node|
        next unless compute_node?(node)

        {
          "node_id" => "node_#{node.fetch("name")}",
          "name" => node.fetch("name"),
          "kind" => node.fetch("kind"),
          "fragment_class" => node.fetch("fragment"),
          "type_tag" => type_name(node.fetch("type")),
          "lifecycle" => "session",
          "obs_kind" => "value_observation",
          "dependencies" => node.fetch("deps").map { |dep| "input:#{dep}" },
          "expression" => compat_expr(node.fetch("expr"))
        }
      end
      temporal_nodes = semantic_nodes.filter_map do |node|
        next unless temporal_node?(node)

        temporal_node_file(node)
      end
      stream_nodes = semantic_nodes.filter_map do |node|
        next unless stream_node?(node)

        stream_node_file(node)
      end

      result = {
        "contract_id" => contract_id,
        "source_contract_ref" => contract_ir.fetch("contract_ref"),
        "name" => contract_id,
        "fragment_class" => contract_ir.fetch("fragment_class"),
        "escape_set" => contract_ir.fetch("escape_boundaries"),
        "lifecycle" => "session",
        "input_ports" => input_ports,
        "output_ports" => output_ports,
        "compute_nodes" => compute_nodes,
        "type_signature" => {
          "inputs" => input_ports.to_h { |port| [port.fetch("name"), port.fetch("type_tag")] },
          "outputs" => output_ports.to_h { |port| [port.fetch("name"), port.fetch("type_tag")] }
        }
      }
      result["temporal_nodes"] = temporal_nodes unless temporal_nodes.empty?
      result["stream_nodes"] = stream_nodes unless stream_nodes.empty?
      result
    end

    def compute_node?(node)
      node.key?("expr") && node.key?("type")
    end

    def temporal_node?(node)
      %w[temporal_input_node temporal_access_node].include?(node.fetch("kind", nil))
    end

    def stream_node?(node)
      %w[stream_input_node window_decl_node fold_stream_node].include?(node.fetch("kind", nil))
    end

    def temporal_node_file(node)
      result = {
        "node_id" => "node_#{node.fetch("name")}",
        "name" => node.fetch("name"),
        "kind" => node.fetch("kind"),
        "fragment_class" => node.fetch("fragment", node.fetch("node_fragment_class", "temporal")),
        "node_fragment_class" => node.fetch("node_fragment_class"),
        "value_fragment_class" => node.fetch("value_fragment_class"),
        "lifecycle" => node.fetch("lifecycle", "session"),
        "obs_kind" => temporal_obs_kind(node),
        "dependencies" => node.fetch("deps", []).map { |dep| "input:#{dep}" },
        "required_capability" => node.fetch("required_capability"),
        "required_caps" => node.fetch("required_caps", [node.fetch("required_capability")]),
        "axis" => node.fetch("axis", node.fetch("temporal_axis", nil))
      }
      result["type_tag"] = type_name(node.fetch("type")) if node.key?("type")
      result["result_type_tag"] = type_name(node.fetch("result_type")) if node.key?("result_type")
      result["store_ref"] = node.fetch("store_ref") if node.key?("store_ref")
      result["source_ref"] = node.fetch("source_ref") if node.key?("source_ref")
      result["temporal_axis"] = node.fetch("temporal_axis") if node.key?("temporal_axis")
      result["coordinate_refs"] = node.fetch("coordinate_refs") if node.key?("coordinate_refs")
      result["as_of_ref"] = node.fetch("as_of_ref") if node.key?("as_of_ref")
      result["valid_time_ref"] = node.fetch("valid_time_ref") if node.key?("valid_time_ref")
      result["transaction_time_ref"] = node.fetch("transaction_time_ref") if node.key?("transaction_time_ref")
      result["evidence_policy"] = node.fetch("evidence_policy") if node.key?("evidence_policy")
      result
    end

    def temporal_obs_kind(node)
      node.fetch("kind") == "temporal_input_node" ? "temporal_source_observation" : "temporal_access_observation"
    end

    def stream_node_file(node)
      name = node.fetch("name", node.fetch("ref", nil))
      result = {
        "node_id" => "node_#{name}",
        "name" => name,
        "kind" => node.fetch("kind"),
        "fragment_class" => node.fetch("fragment", node.fetch("result_fragment", "stream")),
        "lifecycle" => "window",
        "obs_kind" => stream_obs_kind(node),
        "dependencies" => node.fetch("deps", []).map { |dep| "input:#{dep}" }
      }
      result["type_tag"] = type_name(node.fetch("type")) if node.key?("type")
      result["result_type_tag"] = type_name(node.fetch("result_type")) if node.key?("result_type")
      %w[
        window_ref ref key window_kind bounded size period idle on_close stream_ref init fn_ref
        bound event_binding escape_capability result_fragment
      ].each do |key|
        result[key] = node.fetch(key) if node.key?(key)
      end
      result
    end

    def stream_obs_kind(node)
      node.fetch("kind") == "window_decl_node" ? "stream_window_observation" : "stream_replay_metadata"
    end

    def fragment_summary_for(contracts)
      fragment_classes = contracts.map { |contract| contract.fetch("fragment_class") }.uniq.sort
      {
        "fragment_classes" => fragment_classes,
        "max_fragment_class" => max_fragment_class(fragment_classes),
        "precedence_high_to_low" => fragment_precedence
      }
    end

    def max_fragment_class(fragment_classes)
      fragment_precedence.find { |fragment| fragment_classes.include?(fragment) } || "core"
    end

    def fragment_precedence
      %w[oof temporal stream escape core]
    end

    def contract_index_for(contracts)
      contracts.sort_by { |contract| contract.fetch("contract_id") }.to_h do |contract|
        entry = {
          "contract_ref" => contract.fetch("source_contract_ref"),
          "contract_path" => "contracts/#{snake_case(contract.fetch("contract_id"))}.json",
          "fragment_class" => contract.fetch("fragment_class")
        }
        entry["temporal"] = temporal_contract_index(contract) if contract.fetch("fragment_class") == "temporal"
        [contract.fetch("contract_id"), entry]
      end
    end

    def temporal_contract_index(contract)
      temporal_nodes = contract.fetch("temporal_nodes", [])
      access_nodes = temporal_nodes.select { |node| node.fetch("kind") == "temporal_access_node" }
      coordinates = access_nodes.flat_map { |node| temporal_coordinates_for(contract, node) }
      axes = coordinates.map { |coordinate| coordinate.fetch("axis") }.uniq
      required_caps = (
        contract.fetch("escape_set", []).flat_map { |boundary| boundary.fetch("required_caps", []) } +
          temporal_nodes.flat_map { |node| node.fetch("required_caps", []) }
      ).uniq.sort
      hint_axis = access_nodes.map { |node| node.fetch("axis", node.fetch("temporal_axis", nil)) }.compact.uniq
      {
        "axes" => axes.sort_by { |axis| temporal_axis_sort_key(axis) },
        "required_capabilities" => required_caps,
        "coordinates" => coordinates,
        "cache_key_schema_hint" => {
          "schema" => "runtime-cache-key-v1",
          "fragment" => "TEMPORAL",
          "axis" => hint_axis.length == 1 ? hint_axis.first : "mixed",
          "coordinate_names" => coordinates.map { |coord| coord.fetch("name") }
        }
      }
    end

    def temporal_coordinates_for(contract, access_node)
      coordinate_refs = access_node.fetch("coordinate_refs", {})
      coordinate_refs.map do |axis_name, input_name|
        {
          "name" => input_name,
          "axis" => coordinate_axis(access_node, axis_name),
          "source_ref" => "input:#{input_name}",
          "type" => input_type(contract, input_name)
        }
      end.sort_by { |coordinate| temporal_axis_sort_key(coordinate.fetch("axis")) }
    end

    def coordinate_axis(access_node, axis_name)
      access_axis = access_node.fetch("axis", access_node.fetch("temporal_axis", nil))
      access_axis == "bitemporal" ? axis_name : access_axis
    end

    def temporal_axis_sort_key(axis)
      %w[valid_time transaction_time bitemporal].index(axis) || 99
    end

    def input_type(contract, input_name)
      port = contract.fetch("input_ports").find { |input| input.fetch("name") == input_name }
      port ? port.fetch("type_tag") : "Unknown"
    end

    def ports(port_irs)
      port_irs.map do |port|
        {
          "name" => port.fetch("name"),
          "type_tag" => type_name(port.fetch("type")),
          "lifecycle" => port.fetch("lifecycle"),
          "required" => true
        }
      end
    end

    def compat_expr(expr)
      return expr unless expr.is_a?(Hash)

      kind = expr["kind"]
      case kind
      when "call"
        operands = (expr["args"] || []).map { |arg| compat_expr(arg) }
        res = expr.dup
        res["kind"] = "apply"
        res["operator"] = expr["fn"]
        res["operands"] = operands
        res.delete("fn")
        res.delete("args")
        res
      when "ref"
        expr.dup
      when "literal"
        res = expr.dup
        res["type_tag"] = type_name(expr.fetch("resolved_type")) if expr.key?("resolved_type")
        res
      when "field_access"
        res = expr.dup
        res["object"] = compat_expr(expr.fetch("object"))
        res
      else
        res = expr.dup
        expr.each do |k, v|
          if v.is_a?(Hash)
            res[k] = compat_expr(v)
          elsif v.is_a?(Array)
            res[k] = v.map { |item| compat_expr(item) }
          end
        end
        res
      end
    end

    def type_name(type)
      return type if type.is_a?(String)
      return type.to_s unless type.is_a?(Hash)

      if type.key?("constructor")
        element = type.fetch("element_type", nil)
        return element ? "#{type.fetch("constructor")}[#{type_name(element)}]" : type.fetch("constructor")
      end

      params = type.fetch("params", [])
      return type.fetch("name") if params.empty?

      "#{type.fetch("name")}[#{params.map { |param| type_name(param) }.join(",")}]"
    end

    def requirements_for(semantic_ir)
      boundaries = semantic_ir.fetch("contracts").flat_map { |contract| contract.fetch("escape_boundaries", []) }
      required_caps = boundaries.flat_map { |boundary| boundary.fetch("required_caps", []) }.uniq.sort
      fragments = semantic_ir.fetch("contracts").map { |contract| contract.fetch("fragment_class") }.uniq.sort
      temporal_nodes = semantic_ir.fetch("contracts").flat_map { |contract| contract.fetch("nodes", []) }
        .select { |node| temporal_node?(node) }
      temporal_access_nodes = temporal_nodes.select { |node| node.fetch("kind") == "temporal_access_node" }
      temporal_axes = temporal_nodes.map { |node| node.fetch("axis", node.fetch("temporal_axis", nil)) }.compact.uniq.sort
      temporal_caps = required_caps & %w[history_read bihistory_read]
      stream_caps = required_caps & %w[stream_input]
      stream_nodes = semantic_ir.fetch("contracts").flat_map { |contract| contract.fetch("nodes", []) }
        .select { |node| stream_node?(node) }
      stream_windows = stream_nodes.select { |node| node.fetch("kind") == "window_decl_node" }

      {
        "temporal" => {
          "requires_as_of" => temporal_caps.any?,
          "requires_valid_time" => temporal_caps.any?,
          "requires_transaction_time" => required_caps.include?("bihistory_read"),
          "requires_replay" => required_caps.include?("bihistory_read"),
          "requires_snapshot" => false,
          "min_consistency" => "strong",
          "axes" => temporal_axes,
          "coordinate_refs" => temporal_access_nodes.map do |node|
            {
              "node" => node.fetch("name"),
              "axis" => node.fetch("axis", node.fetch("temporal_axis")),
              "coordinates" => node.fetch("coordinate_refs", {})
            }
          end,
          "windows" => stream_windows.map { |node| stream_window_requirement(node) },
          "slices" => []
        },
        "lifecycle" => {
          "min_lifecycle" => "local",
          "has_audit" => temporal_caps.any?,
          "has_window" => stream_caps.any?
        },
        "fragments" => fragments,
        "capabilities" => {
          "required_caps" => required_caps,
          "effect_kinds" => effect_kinds_for(boundaries)
        },
        "effects" => [],
        "ffi" => [],
        "required_tbackend_caps" => {
          "read_as_of" => temporal_caps.any?,
          "append_atomic" => false,
          "replay_enabled" => required_caps.include?("bihistory_read"),
          "snapshot_enabled" => false,
          "compact_enabled" => false,
          "subscribe_enabled" => false,
          "consistency" => "strong"
        }
      }
    end

    def effect_kinds_for(boundaries)
      boundaries.flat_map { |boundary| boundary.fetch("produces", []) }.uniq.sort
    end

    def stream_window_requirement(node)
      result = {
        "ref" => node.fetch("ref"),
        "kind" => node.fetch("window_kind", nil),
        "bounded" => node.fetch("bounded", false)
      }
      %w[size period idle on_close].each do |key|
        result[key] = node.fetch(key) if node.key?(key)
      end
      result.compact
    end

    def classified_ast_for(report, semantic_ir, contract_ids, fragment_class)
      {
        "kind" => "classified_program",
        "format_version" => "0.1.0",
        "program_id" => semantic_ir.fetch("program_id"),
        "source_hash" => semantic_ir.fetch("source_hash"),
        "source_path" => semantic_ir.fetch("source_path"),
        "pass_result" => report.fetch("pass_result"),
        "semantic_ir_ref" => report.fetch("semantic_ir_ref"),
        "compilation_report_ref" => semantic_ir.fetch("compilation_report_ref"),
        "fragment_class" => fragment_class,
        "oof_count" => 0,
        "contracts" => contract_ids,
        "loadable_contracts" => contract_ids
      }
    end

    def compatibility_metadata_for(report, semantic_ir)
      metadata = {
        "kind" => "igapp_compatibility_metadata",
        "format_version" => "0.1.0",
        "canonical_semantic_ir_ref" => semantic_ir.fetch("program_id"),
        "compilation_report_ref" => report.fetch("program_id"),
        "loader_shape" => "runtime_machine_memory_proof.prop0191_direct_v0",
        "canonical_artifact" => "semantic_ir_program.json",
        "runtime_compatibility_artifact" => nil,
        "notes" => [
          "semantic_ir_program.json preserves PROP-019.1 envelope",
          "RuntimeMachine proof loader reads semantic_ir_program.json directly"
        ]
      }
      if temporal_artifact?(semantic_ir)
        metadata["runtime_execution"] = {
          "status" => "unsupported",
          "guard_policy" => "load_accept_evaluate_refuse",
          "guard_at" => "evaluate",
          "load" => {
            "decision" => "accept_for_inspection",
            "requires_contract_index" => true
          },
          "evaluate" => {
            "decision" => "refuse_temporal_contract",
            "reason_code" => "runtime.temporal_execution_unsupported"
          },
          "reason" => "temporal SemanticIR assembly proof preserves artifact shape only; RuntimeMachine temporal execution is out of scope"
        }
        metadata["notes"] += [
          "temporal_input_node and temporal_access_node are preserved as non-compute contract nodes",
          "temporal runtime execution requires a separate RuntimeMachine temporal adapter/hook slice"
        ]
      end
      metadata
    end

    def temporal_artifact?(semantic_ir)
      semantic_ir.fetch("contracts").any? do |contract|
        contract.fetch("nodes", []).any? { |node| temporal_node?(node) }
      end
    end

    def write_artifact(case_name, artifact)
      target = @out_dir / "#{case_name}.igapp"
      write_artifact_to(target, artifact)
    end

    def write_artifact_to(target, artifact)
      FileUtils.rm_rf(target)
      FileUtils.mkdir_p(target / "contracts")

      write_json(target / "manifest.json", artifact.fetch("manifest"))
      write_json(target / "semantic_ir_program.json", artifact.fetch("semantic_ir_program"))
      write_json(target / "compilation_report.json", artifact.fetch("compilation_report"))
      write_json(target / "requirements.json", artifact.fetch("requirements"))
      write_json(target / "diagnostics.json", artifact.fetch("diagnostics"))
      write_json(target / "classified_ast.json", artifact.fetch("classified_ast"))
      write_json(target / "projections.json", artifact.fetch("projections"))
      write_json(target / "compatibility_metadata.json", artifact.fetch("compatibility_metadata"))
      artifact.fetch("contracts").each do |contract|
        write_json(target / "contracts/#{snake_case(contract.fetch("contract_id"))}.json", contract)
      end
    end

    def write_json(path, value)
      File.write(path, Canonical.json(value))
    end

    def snake_case(value)
      value.gsub(/([a-z])([A-Z])/, "\\1_\\2").downcase
    end

    def artifact_summary(case_name, artifact)
      {
        "case" => case_name,
        "status" => "assembled",
        "igapp_dir" => (@out_dir / "#{case_name}.igapp").relative_path_from(ROOT).to_s,
        "program_id" => artifact.fetch("manifest").fetch("program_id"),
        "artifact_hash" => artifact.fetch("manifest").fetch("artifact_hash"),
        "semantic_ir_ref" => artifact.fetch("manifest").fetch("semantic_ir_ref"),
        "compilation_report_ref" => artifact.fetch("manifest").fetch("compilation_report_ref"),
        "contracts" => artifact.fetch("manifest").fetch("contracts"),
        "files" => artifact_files(case_name)
      }
    end

    def artifact_summary_for_target(case_name, artifact, target)
      {
        "case" => case_name,
        "status" => "assembled",
        "igapp_dir" => target.to_s,
        "program_id" => artifact.fetch("manifest").fetch("program_id"),
        "artifact_hash" => artifact.fetch("manifest").fetch("artifact_hash"),
        "semantic_ir_ref" => artifact.fetch("manifest").fetch("semantic_ir_ref"),
        "compilation_report_ref" => artifact.fetch("manifest").fetch("compilation_report_ref"),
        "contracts" => artifact.fetch("manifest").fetch("contracts"),
        "files" => target.find.select(&:file?).map { |path| path.relative_path_from(target).to_s }.sort
      }
    end

    def artifact_files(case_name)
      target = @out_dir / "#{case_name}.igapp"
      target.find.select(&:file?).map { |path| path.relative_path_from(target).to_s }.sort
    end
  end

  IgappAssembler = Assembler
end
