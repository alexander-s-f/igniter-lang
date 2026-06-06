# frozen_string_literal: true

# Internal profile-assembly source packet.
#
# ISOLATION CONTRACT — this file must not:
#   - be required from lib/igniter_lang.rb
#   - integrate with parser/classifier/TypeChecker/SemanticIR/assembler/orchestrator
#   - expose public API or CLI
#   - read paths, manifests, loader reports, CompatibilityReports, or runtime state
#   - write .igapp, .ilk, reports, sidecars, goldens, diagnostics, or CompilerResult fields
#
# Authorized by: LANG-R128-A
# Track: internal-profile-assembly-source-packet-implementation-v0
#
# Lifecycle wording:
#   implementation_candidate = internal implementation boundary state
#   finalized_internal       = internal assembly state only; not PROP-036
#                              finalization, not compiler_profile_id, and not
#                              manifest/profile identity.

module IgniterLang
  class InternalProfileAssemblySourcePacket
    KIND = "compiler_profile_oof_registry_source_input"
    FORMAT_VERSION = "0.1.0"
    HELPER_KIND = "oof_fragment_registry_source"
    VALIDATION_TARGET = "oof_fragment_registry_source_envelope_helper"

    IMPLEMENTATION_CANDIDATE = "implementation_candidate"
    FINALIZED_INTERNAL = "finalized_internal"
    LIFECYCLE_STATES = [IMPLEMENTATION_CANDIDATE, FINALIZED_INTERNAL].freeze

    DEFAULT_CLOSED_SURFACE_ASSERTIONS = {
      "compiler_integration" => false,
      "public_api_cli" => false,
      "loader_report" => false,
      "compatibility_report" => false,
      "igapp_mutation" => false,
      "prop036_manifest_change" => false,
      "prop038_validator_report_change" => false,
      "runtime_behavior" => false,
      "production_behavior" => false,
      "spark_surface" => false
    }.freeze

    def self.build(authority:, profile_candidate:, pack_descriptor_candidates:,
      lifecycle_state: IMPLEMENTATION_CANDIDATE, closed_surface_assertions: {},
      excluded_namespaces: nil)
      new(
        authority: authority,
        profile_candidate: profile_candidate,
        pack_descriptor_candidates: pack_descriptor_candidates,
        lifecycle_state: lifecycle_state,
        closed_surface_assertions: DEFAULT_CLOSED_SURFACE_ASSERTIONS.merge(
          stringify_keys(closed_surface_assertions)
        ),
        excluded_namespaces: excluded_namespaces
      )
    end

    def initialize(authority:, profile_candidate:, pack_descriptor_candidates:,
      lifecycle_state:, closed_surface_assertions:, excluded_namespaces:)
      unless LIFECYCLE_STATES.include?(lifecycle_state)
        raise ArgumentError, "unsupported lifecycle_state #{lifecycle_state.inspect}"
      end

      @authority = deep_copy(authority)
      @profile_candidate = deep_copy(profile_candidate)
      @pack_descriptor_candidates = deep_copy(pack_descriptor_candidates)
      @lifecycle_state = lifecycle_state
      @closed_surface_assertions = deep_copy(closed_surface_assertions)
      @excluded_namespaces = deep_copy(excluded_namespaces)
    end

    attr_reader :lifecycle_state

    def to_h
      packet = {
        "kind" => KIND,
        "format_version" => FORMAT_VERSION,
        "lifecycle_state" => lifecycle_state,
        "authority" => deep_copy(@authority),
        "profile_candidate" => deep_copy(@profile_candidate),
        "pack_descriptor_candidates" => deep_copy(@pack_descriptor_candidates),
        "validation_target" => VALIDATION_TARGET,
        "closed_surface_assertions" => deep_copy(@closed_surface_assertions)
      }
      packet["excluded_namespaces"] = deep_copy(@excluded_namespaces) if @excluded_namespaces
      packet
    end

    def to_helper_envelopes
      packet = to_h
      common = {
        "kind" => HELPER_KIND,
        "format_version" => FORMAT_VERSION,
        "authority" => packet.fetch("authority"),
        "closed_surface_assertions" => packet.fetch("closed_surface_assertions")
      }
      profile = packet.fetch("profile_candidate")
      pack_candidates = packet.fetch("pack_descriptor_candidates")

      profile_envelope = common.merge(
        "source_mode" => "profile_candidate",
        "profile_ref" => profile.fetch("profile_ref"),
        "profile_contract_ref" => profile["profile_contract_ref"],
        "row_authority_policy" => profile.fetch("row_authority_policy"),
        "selected_pack_refs" => profile.fetch("selected_pack_refs"),
        "pack_order" => profile.fetch("pack_order"),
        "conflict_policy" => profile.fetch("conflict_policy"),
        "pack_descriptor_candidates" => pack_candidates
      )
      profile_envelope["excluded_namespaces"] = packet.fetch("excluded_namespaces") if packet.key?("excluded_namespaces")

      pack_envelopes = pack_candidates.map do |pack|
        common.merge(
          "source_mode" => "pack_descriptor_candidate",
          "pack_ref" => pack.fetch("pack_ref"),
          "slot_name" => pack.fetch("slot_name"),
          "owner_pack_or_boundary" => pack.fetch("owner_pack_or_boundary"),
          "row_authority_policy" => pack.fetch("row_authority_policy"),
          "owned_oof_descriptors" => pack.fetch("owned_oof_descriptors"),
          "owned_fragment_rows" => pack.fetch("owned_fragment_rows"),
          "owned_support_markers" => pack.fetch("owned_support_markers")
        )
      end

      {
        "kind" => "mapped_oof_fragment_registry_source_envelopes",
        "format_version" => FORMAT_VERSION,
        "source_input_kind" => KIND,
        "profile_envelope" => profile_envelope,
        "pack_descriptor_envelopes" => pack_envelopes
      }
    end

    def validate_with(registry_validator:)
      helper_envelopes = to_helper_envelopes
      profile_validation = registry_validator.validate_source_envelope(
        helper_envelopes.fetch("profile_envelope")
      )
      pack_validations = helper_envelopes.fetch("pack_descriptor_envelopes").map do |envelope|
        registry_validator.validate_source_envelope(envelope)
      end
      valid = profile_validation.fetch("valid") &&
        pack_validations.all? { |result| result.fetch("valid") }
      result_state = valid ? FINALIZED_INTERNAL : lifecycle_state

      {
        "kind" => "internal_profile_assembly_source_packet_validation",
        "format_version" => FORMAT_VERSION,
        "valid" => valid,
        "lifecycle_state" => lifecycle_state,
        "result_lifecycle_state" => result_state,
        "finalized_internal_meaning" =>
          "internal assembly state only; not PROP-036 finalization, not compiler_profile_id, " \
          "and not manifest/profile identity",
        "source_packet" => to_h,
        "helper_envelopes" => helper_envelopes,
        "profile_validation" => profile_validation,
        "pack_descriptor_validations" => pack_validations,
        "closed_surface_assertions" => deep_copy(@closed_surface_assertions)
      }
    end

    def self.stringify_keys(hash)
      hash.to_h.transform_keys(&:to_s)
    end

    def deep_copy(value)
      Marshal.load(Marshal.dump(value))
    end

    private :deep_copy
  end
end
