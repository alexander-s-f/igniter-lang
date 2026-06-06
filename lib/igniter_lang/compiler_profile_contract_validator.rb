# frozen_string_literal: true

require "digest"
require "json"
require "set"

module IgniterLang
  module CompilerProfileContractValidator
    RESULT_KIND = "compiler_profile_contract_validation_result"
    FORMAT_VERSION = "0.1.0"
    DEFAULT_DIGEST_REFERENCE_POLICY = :prop038_24_plus

    REQUIRED_SLOTS = %w[core oof_registry fragment_registry escape_boundary].freeze
    OPTIONAL_SLOTS = %w[
      contract_modifiers temporal stream olap invariant assumptions evidence_observation pipeline
    ].freeze
    ALL_SLOTS = (REQUIRED_SLOTS + OPTIONAL_SLOTS).freeze

    DESCRIPTOR_DIGEST_PATTERN = /\Acompiler_profile_descriptor\/sha256:[0-9a-f]{24,}\z/
    FINALIZATION_PAYLOAD_DIGEST_PATTERN = /\Asha256:[0-9a-f]{64}\z/
    CONTRACT_DIGEST_PREFIX = "compiler_profile_contract/sha256:"
    CONTRACT_DIGEST_PATTERN = /\Acompiler_profile_contract\/sha256:[0-9a-f]{24,}\z/
    SUPPORTED_DIGEST_REFERENCE_POLICIES = %w[prop038_24_plus].freeze
    CANONICAL_CONTRACT_FIELDS = %w[
      kind
      format_version
      profile_namespace
      profile_kind
      compiler_profile_id
      descriptor_digest
      finalization_payload_digest
      required_slot_schema
      slot_order
      slot_assignments
      strict_registries
      ordered_rule_graph
      non_authority
    ].freeze

    def self.validate(contract, digest_reference_policy: DEFAULT_DIGEST_REFERENCE_POLICY)
      policy = digest_reference_policy.to_s
      diagnostics = []

      unless contract.is_a?(Hash)
        diagnostics << diagnostic("wrong_kind", "expected compiler_profile_contract", "kind")
        return result(diagnostics, policy)
      end

      diagnostics << diagnostic("wrong_kind", "expected compiler_profile_contract", "kind") unless contract["kind"] == "compiler_profile_contract"
      diagnostics << diagnostic("unsupported_format_version", "expected format_version 0.1.0", "format_version") unless contract["format_version"] == FORMAT_VERSION
      diagnostics << diagnostic("descriptor_digest_invalid", "descriptor_digest must be compiler_profile_descriptor/sha256:<hex>", "descriptor_digest") unless contract["descriptor_digest"].to_s.match?(DESCRIPTOR_DIGEST_PATTERN)
      diagnostics << diagnostic("finalization_payload_digest_invalid", "finalization_payload_digest must be sha256:<64 hex>", "finalization_payload_digest") unless contract["finalization_payload_digest"].to_s.match?(FINALIZATION_PAYLOAD_DIGEST_PATTERN)

      contract_digest_recomputable = validate_contract_digest_shape(diagnostics, contract, policy)

      slot_order = Array(contract["slot_order"])
      slot_assignments = contract["slot_assignments"] || {}
      Array(contract.dig("required_slot_schema", "required_slots")).each do |slot|
        unless slot_order.include?(slot) && slot_assignments.key?(slot)
          diagnostics << diagnostic("missing_required_slot", "required slot #{slot.inspect} is missing from slot_order or slot_assignments", "slot_assignments.#{slot}")
        end
      end

      strict_registries = contract["strict_registries"] || {}
      strict_registries.each do |registry_name, entries|
        seen = {}
        Array(entries).each do |entry|
          key = entry["key"]
          if seen.key?(key)
            diagnostics << diagnostic("duplicate_strict_key", "strict registry #{registry_name} has duplicate key #{key.inspect}", "strict_registries.#{registry_name}.#{key}")
          end
          seen[key] = true
        end
      end

      rules = Array(contract.dig("ordered_rule_graph", "rules"))
      rule_ids = rules.map { |rule| rule["rule_id"] }
      rules.each do |rule|
        (Array(rule["before"]) + Array(rule["after"])).each do |ref|
          unless rule_ids.include?(ref)
            diagnostics << diagnostic("missing_rule_reference", "ordered rule #{rule["rule_id"]} references missing rule #{ref.inspect}", "ordered_rule_graph.rules.#{rule["rule_id"]}")
          end
        end
      end

      cycle = find_rule_cycle(rules)
      diagnostics << diagnostic("rule_cycle", "ordered rule graph contains cycle: #{cycle.join(" -> ")}", "ordered_rule_graph.rules") if cycle

      non_authority = contract["non_authority"] || {}
      diagnostics << diagnostic("runtime_authority_forbidden", "compiler profile contract cannot grant runtime authority", "non_authority.runtime_authority_granted") if non_authority["runtime_authority_granted"]
      diagnostics << diagnostic("dispatch_migration_forbidden", "compiler profile contract cannot authorize dispatch migration", "non_authority.dispatch_migration_authorized") if non_authority["dispatch_migration_authorized"]

      validate_contract_digest_match(diagnostics, contract) if contract_digest_recomputable

      result(diagnostics, policy)
    end

    class << self
      private

      def validate_contract_digest_shape(diagnostics, contract, policy)
        unless SUPPORTED_DIGEST_REFERENCE_POLICIES.include?(policy)
          diagnostics << diagnostic(
            "contract_digest_policy_unsupported",
            "unsupported contract_digest policy #{policy.inspect}",
            "digest_reference_policy"
          )
          return false
        end

        unless contract["contract_digest"].to_s.match?(CONTRACT_DIGEST_PATTERN)
          diagnostics << diagnostic(
            "contract_digest_invalid",
            "contract_digest must be compiler_profile_contract/sha256:<24+ lowercase hex>",
            "contract_digest"
          )
          return false
        end

        true
      end

      def validate_contract_digest_match(diagnostics, contract)
        declared_hex = contract["contract_digest"].to_s.delete_prefix(CONTRACT_DIGEST_PREFIX)
        computed_hex = recomputed_contract_digest_hex(contract)
        return if computed_hex.start_with?(declared_hex)

        diagnostics << diagnostic(
          "contract_digest_mismatch",
          "declared contract_digest does not match recomputed canonical contract digest",
          "contract_digest"
        )
      rescue
        diagnostics << diagnostic(
          "contract_digest_recompute_unavailable",
          "contract digest recompute requested but canonicalization is unavailable",
          "contract_digest"
        )
      end

      def diagnostic(code, message, path = nil)
        {
          "code" => "compiler_profile_contract.#{code}",
          "message" => message,
          "path" => path
        }
      end

      def result(diagnostics, policy)
        {
          "kind" => RESULT_KIND,
          "format_version" => FORMAT_VERSION,
          "valid" => diagnostics.empty?,
          "diagnostics" => diagnostics,
          "diagnostic_codes" => diagnostics.map { |diagnostic| diagnostic.fetch("code") },
          "digest_reference_policy" => policy,
          "compiler_integrated" => false,
          "compile_refusal_authorized" => false
        }
      end

      def recomputed_contract_digest_hex(contract)
        Digest::SHA256.hexdigest(canonical_contract_json(contract))
      end

      def canonical_contract_json(contract)
        JSON.generate(canonical_contract_material(contract))
      end

      def canonical_contract_material(contract)
        material = CANONICAL_CONTRACT_FIELDS.to_h do |field|
          [field, canonicalize_for_digest(contract[field])]
        end
        material["strict_registries"] = canonical_strict_registries(contract["strict_registries"] || {})
        material["ordered_rule_graph"] = canonical_ordered_rule_graph(contract["ordered_rule_graph"] || {})
        canonicalize_for_digest(material)
      end

      def canonical_strict_registries(registries)
        unless registries.is_a?(Hash)
          raise TypeError, "strict_registries must be a Hash for canonicalization"
        end

        registries.keys.sort_by(&:to_s).to_h do |key|
          registry_name = key.to_s
          entries = Array(registries[key]).map { |entry| canonicalize_for_digest(entry) }
          [
            registry_name,
            entries.sort_by do |entry|
              [
                entry.fetch("key", "").to_s,
                entry.fetch("owner_slot", "").to_s,
                entry.fetch("rule_ref", "").to_s
              ]
            end
          ]
        end
      end

      def canonical_ordered_rule_graph(graph)
        unless graph.is_a?(Hash)
          raise TypeError, "ordered_rule_graph must be a Hash for canonicalization"
        end

        rules = Array(graph["rules"]).map do |rule|
          canonical_rule(rule)
        end
        { "rules" => rules.sort_by { |rule| rule.fetch("rule_id", "").to_s } }
      end

      def canonical_rule(rule)
        unless rule.is_a?(Hash)
          raise TypeError, "ordered rule must be a Hash for canonicalization"
        end

        normalized = rule.keys.sort_by(&:to_s).to_h do |key|
          key_name = key.to_s
          value = if key_name == "before" || key_name == "after"
                    Array(rule[key]).map(&:to_s).uniq.sort
                  else
                    canonicalize_for_digest(rule[key])
                  end
          [key_name, value]
        end
        normalized["before"] = [] unless normalized.key?("before")
        normalized["after"] = [] unless normalized.key?("after")
        normalized
      end

      def canonicalize_for_digest(value)
        case value
        when Hash
          value.keys.sort_by(&:to_s).to_h do |key|
            [key.to_s, canonicalize_for_digest(value[key])]
          end
        when Array
          value.map { |entry| canonicalize_for_digest(entry) }
        when String, Integer, Float, TrueClass, FalseClass, NilClass
          value
        else
          raise TypeError, "unsupported canonical contract value #{value.class}"
        end
      end

      def find_rule_cycle(rules)
        ids = rules.map { |rule| rule.fetch("rule_id") }
        edges = Hash.new { |hash, key| hash[key] = [] }
        rules.each do |rule|
          rule.fetch("before", []).each { |target| edges[rule.fetch("rule_id")] << target }
          rule.fetch("after", []).each { |source| edges[source] << rule.fetch("rule_id") }
        end

        visiting = Set.new
        visited = Set.new
        stack = []

        visit = lambda do |id|
          return nil if visited.include?(id)
          if visiting.include?(id)
            cycle_start = stack.index(id) || 0
            return stack[cycle_start..] + [id]
          end

          visiting << id
          stack << id
          edges[id].each do |target|
            next unless ids.include?(target)

            cycle = visit.call(target)
            return cycle if cycle
          end
          stack.pop
          visiting.delete(id)
          visited << id
          nil
        end

        ids.each do |id|
          cycle = visit.call(id)
          return cycle if cycle
        end
        nil
      end
    end
  end
end
