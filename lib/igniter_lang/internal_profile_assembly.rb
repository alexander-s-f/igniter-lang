# frozen_string_literal: true

# Internal profile assembly boundary.
#
# ISOLATION CONTRACT — this file must not:
#   - be required from lib/igniter_lang.rb
#   - integrate with parser/classifier/TypeChecker/SemanticIR/assembler/orchestrator
#   - expose public API or CLI
#   - read paths, manifests, loader reports, CompatibilityReports, or runtime state
#   - write .igapp, .ilk, reports, sidecars, goldens, diagnostics, or CompilerResult fields
#
# Authorized by: LANG-R132-A
# Track: internal-profile-assembly-boundary-implementation-v0

require "digest"
require "json"

module IgniterLang
  class InternalProfileAssembly
    KIND = "internal_profile_assembly_result"
    FORMAT_VERSION = "0.1.0"

    SOURCE_PACKET_KIND = "compiler_profile_oof_registry_source_input"
    IMPLEMENTATION_CANDIDATE = "implementation_candidate"
    FINALIZED_INTERNAL = "finalized_internal"

    FINALIZED_INTERNAL_MEANING =
      "internal assembly state only; not PROP-036 finalization, not compiler_profile_id, " \
      "and not manifest/profile identity"

    CLOSED_SURFACE_ASSERTIONS = {
      "root_require" => false,
      "compiler_pipeline_usage" => false,
      "public_api_cli" => false,
      "loader_report" => false,
      "compatibility_report" => false,
      "igapp_mutation" => false,
      "manifest_mutation" => false,
      "prop036_mutation" => false,
      "prop038_mutation" => false,
      "runtime_behavior" => false,
      "production_behavior" => false,
      "spark_surface" => false
    }.freeze

    DIAG_INVALID_SOURCE_PACKET = "internal_profile_assembly.invalid_source_packet"
    DIAG_INVALID_LIFECYCLE_STATE = "internal_profile_assembly.invalid_lifecycle_state"
    DIAG_PACKET_MAPPING_FAILED = "internal_profile_assembly.packet_mapping_failed"
    DIAG_PACKET_VALIDATION_FAILED = "internal_profile_assembly.packet_validation_failed"

    def self.assemble(source_packet:, registry_validator: IgniterLang::OOFFragmentRegistry.new)
      new(source_packet: source_packet, registry_validator: registry_validator).assemble
    end

    def initialize(source_packet:, registry_validator:)
      @source_packet = source_packet
      @registry_validator = registry_validator
    end

    def assemble
      diagnostics = []
      packet_hash = nil
      helper_envelopes = nil
      validation = nil
      input_lifecycle_state = lifecycle_state_of(@source_packet)

      unless source_packet_compatible?(@source_packet)
        diagnostics << diag(DIAG_INVALID_SOURCE_PACKET,
          "source_packet must support lifecycle_state, to_h, to_helper_envelopes, and validate_with")
        return build_result(false, input_lifecycle_state, diagnostics, packet_hash, helper_envelopes, validation)
      end

      if input_lifecycle_state != IMPLEMENTATION_CANDIDATE
        diagnostics << diag(DIAG_INVALID_LIFECYCLE_STATE,
          "source_packet lifecycle_state must be #{IMPLEMENTATION_CANDIDATE.inspect}, " \
          "got #{input_lifecycle_state.inspect}")
      end

      begin
        packet_hash = @source_packet.to_h
        helper_envelopes = @source_packet.to_helper_envelopes
      rescue StandardError => e
        diagnostics << diag(DIAG_PACKET_MAPPING_FAILED, "#{e.class}: #{e.message}")
        return build_result(false, input_lifecycle_state, diagnostics, packet_hash, helper_envelopes, validation)
      end

      unless packet_hash.is_a?(Hash) && packet_hash["kind"] == SOURCE_PACKET_KIND
        diagnostics << diag(DIAG_INVALID_SOURCE_PACKET,
          "source_packet.to_h must return kind #{SOURCE_PACKET_KIND.inspect}")
      end

      begin
        validation = @source_packet.validate_with(registry_validator: @registry_validator)
      rescue StandardError => e
        diagnostics << diag(DIAG_PACKET_VALIDATION_FAILED, "#{e.class}: #{e.message}")
        return build_result(false, input_lifecycle_state, diagnostics, packet_hash, helper_envelopes, validation)
      end

      diagnostics.concat(internal_diagnostics_from(validation))
      valid = diagnostics.empty? && validation.fetch("valid", false)

      build_result(valid, input_lifecycle_state, diagnostics, packet_hash, helper_envelopes, validation)
    end

    private

    def source_packet_compatible?(packet)
      %i[
        lifecycle_state
        to_h
        to_helper_envelopes
        validate_with
      ].all? { |method_name| packet.respond_to?(method_name) }
    end

    def lifecycle_state_of(packet)
      return nil unless packet.respond_to?(:lifecycle_state)

      packet.lifecycle_state
    end

    def build_result(valid, input_lifecycle_state, diagnostics, packet_hash, helper_envelopes, validation)
      {
        "kind" => KIND,
        "format_version" => FORMAT_VERSION,
        "valid" => valid,
        "lifecycle_state" => valid ? FINALIZED_INTERNAL : non_final_lifecycle(input_lifecycle_state),
        "input_lifecycle_state" => input_lifecycle_state,
        "packet_kind" => packet_hash.is_a?(Hash) ? packet_hash["kind"] : nil,
        "packet_digest" => packet_hash ? digest(packet_hash) : nil,
        "helper_envelopes_digest" => helper_envelopes ? digest(helper_envelopes) : nil,
        "profile_validation" => validation.is_a?(Hash) ? validation["profile_validation"] : nil,
        "pack_descriptor_validations" => validation.is_a?(Hash) ? Array(validation["pack_descriptor_validations"]) : [],
        "diagnostics" => diagnostics,
        "finalized_internal_meaning" => FINALIZED_INTERNAL_MEANING,
        "closed_surface_assertions" => deep_copy(CLOSED_SURFACE_ASSERTIONS)
      }
    end

    def internal_diagnostics_from(validation)
      return [diag(DIAG_PACKET_VALIDATION_FAILED, "source_packet.validate_with must return a Hash")] unless validation.is_a?(Hash)
      return [] if validation.fetch("valid", false)

      diagnostics = []
      profile_diags = Array(validation.dig("profile_validation", "source_diagnostics"))
      diagnostics.concat(profile_diags.map { |source_diag| source_validation_diag("profile_validation", source_diag) })

      Array(validation["pack_descriptor_validations"]).each_with_index do |pack_validation, index|
        Array(pack_validation["source_diagnostics"]).each do |source_diag|
          diagnostics << source_validation_diag("pack_descriptor_validations[#{index}]", source_diag)
        end
      end

      diagnostics << diag(DIAG_PACKET_VALIDATION_FAILED, "source packet validation failed") if diagnostics.empty?
      diagnostics
    end

    def non_final_lifecycle(input_lifecycle_state)
      return IMPLEMENTATION_CANDIDATE if input_lifecycle_state == IMPLEMENTATION_CANDIDATE

      "invalid"
    end

    def source_validation_diag(path, source_diag)
      {
        "code" => DIAG_PACKET_VALIDATION_FAILED,
        "path" => path,
        "source_code" => source_diag.fetch("code", nil),
        "message" => source_diag.fetch("message", "source packet validation failed")
      }
    end

    def diag(code, message)
      {
        "code" => code,
        "message" => message
      }
    end

    def digest(value)
      Digest::SHA256.hexdigest(JSON.generate(canonicalize(value)))[0, 24]
    end

    def canonicalize(value)
      case value
      when Hash
        value.keys.sort.to_h { |key| [key, canonicalize(value[key])] }
      when Array
        value.map { |inner| canonicalize(inner) }
      else
        value
      end
    end

    def deep_copy(value)
      Marshal.load(Marshal.dump(value))
    end
  end
end
