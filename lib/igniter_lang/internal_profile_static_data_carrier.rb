# frozen_string_literal: true

require "digest"
require "json"
require_relative "internal_profile_assembly_source_packet"

module IgniterLang
  class InternalProfileStaticDataCarrier
    KIND = "internal_profile_static_data_carrier"
    FORMAT_VERSION = "0.1.0"
    STATIC_DATA_STATUSES = ["proof_local_only", "internal_test_seam_only"].freeze

    DIAG_INVALID_SHAPE = "internal_profile_static_data_carrier.invalid_shape"
    DIAG_UNSUPPORTED_KIND = "internal_profile_static_data_carrier.unsupported_kind"
    DIAG_UNSUPPORTED_FORMAT_VERSION =
      "internal_profile_static_data_carrier.unsupported_format_version"
    DIAG_UNSUPPORTED_STATIC_DATA_STATUS =
      "internal_profile_static_data_carrier.unsupported_static_data_status"
    DIAG_INVALID_AUTHORITY = "internal_profile_static_data_carrier.invalid_authority"
    DIAG_MISSING_PROFILE_CANDIDATE =
      "internal_profile_static_data_carrier.missing_profile_candidate"
    DIAG_MISSING_PACK_DESCRIPTOR_CANDIDATES =
      "internal_profile_static_data_carrier.missing_pack_descriptor_candidates"
    DIAG_SURFACE_OPEN = "internal_profile_static_data_carrier.surface_open"
    DIAG_FORBIDDEN_FIELD = "internal_profile_static_data_carrier.forbidden_field"
    DIAG_PACKET_BUILD_FAILED = "internal_profile_static_data_carrier.packet_build_failed"

    ACCEPTED_AUTHORITY_KINDS = ["proof_only", "design_accepted"].freeze
    ACCEPTED_CANON_STATUSES = ["non_canon", "accepted_design"].freeze

    FORBIDDEN_FIELDS = %w[
      compiler_profile_id
      compiler_profile_id_source
      compiler_profile_source
      profile_source
      default_profile
      named_profile
      profile_discovery
      igapp_path
      compilation_report_path
      loader_report
      compatibility_report
      compiler_result
      manifest
      sidecar
      artifact_hash
      runtime_ready
      production_ready
      spark_ready
      demo_ready
      public
      discovery
      loader
      report
      artifact
      runtime
      spark
      production
      demo
    ].freeze

    def self.build(static_data:)
      new(static_data)
    end

    def initialize(static_data)
      @raw_static_data = static_data
      @static_data = normalize_hash(static_data)
      @packet_build_diagnostics = []
      @diagnostics = validate_static_data
    end

    def to_h
      {
        "kind" => KIND,
        "format_version" => FORMAT_VERSION,
        "valid" => valid_shape?,
        "static_data_status" => static_data_status_output,
        "authority" => authority_output,
        "profile_candidate" => deep_copy(@static_data["profile_candidate"]),
        "pack_descriptor_candidates" => deep_copy(pack_descriptor_candidates),
        "excluded_namespaces" => deep_copy(excluded_namespaces),
        "diagnostics" => diagnostics,
        "static_data_digest" => static_data_digest,
        "closed_surface_assertions" => closed_surface_assertions_output
      }
    end

    def valid_shape?
      diagnostics.empty?
    end

    def diagnostics
      deep_copy(@diagnostics + @packet_build_diagnostics)
    end

    def to_source_packet
      return nil unless valid_shape?

      IgniterLang::InternalProfileAssemblySourcePacket.build(
        authority: deep_copy(@static_data.fetch("authority")),
        profile_candidate: deep_copy(@static_data.fetch("profile_candidate")),
        pack_descriptor_candidates: deep_copy(@static_data.fetch("pack_descriptor_candidates")),
        lifecycle_state: IgniterLang::InternalProfileAssemblySourcePacket::IMPLEMENTATION_CANDIDATE,
        closed_surface_assertions: deep_copy(closed_surface_assertions),
        excluded_namespaces: deep_copy(excluded_namespaces)
      )
    rescue StandardError => e
      record_packet_build_failure(e)
      nil
    end

    def static_data_digest
      Digest::SHA256.hexdigest(JSON.generate(canonicalize(carrier_material)))[0, 24]
    end

    private

    def validate_static_data
      diags = []

      unless @raw_static_data.is_a?(Hash)
        diags << diag(DIAG_INVALID_SHAPE, "static_data must be a Hash")
        return diags
      end

      unless @static_data["kind"] == KIND
        diags << diag(DIAG_UNSUPPORTED_KIND, "static_data kind is not supported")
      end

      unless @static_data["format_version"] == FORMAT_VERSION
        diags << diag(DIAG_UNSUPPORTED_FORMAT_VERSION, "static_data format_version is not supported")
      end

      unless STATIC_DATA_STATUSES.include?(@static_data["static_data_status"])
        diags << diag(DIAG_UNSUPPORTED_STATIC_DATA_STATUS, "static_data status is not supported")
      end

      diags << diag(DIAG_INVALID_AUTHORITY, "authority is outside internal proof/design scope") unless valid_authority?

      unless @static_data["profile_candidate"].is_a?(Hash)
        diags << diag(DIAG_MISSING_PROFILE_CANDIDATE, "profile_candidate must be present")
      end

      unless @static_data["pack_descriptor_candidates"].is_a?(Array) &&
          @static_data["pack_descriptor_candidates"].any?
        diags << diag(DIAG_MISSING_PACK_DESCRIPTOR_CANDIDATES,
          "pack_descriptor_candidates must be a non-empty Array")
      end

      unless closed_surface_assertions.is_a?(Hash)
        diags << diag(DIAG_INVALID_SHAPE, "closed_surface_assertions must be a Hash when present")
      end

      if closed_surface_assertions.is_a?(Hash) &&
          closed_surface_assertions.values.any? { |value| value == true }
        diags << diag(DIAG_SURFACE_OPEN, "closed_surface_assertions must remain closed")
      end

      forbidden_field_count.times do
        diags << diag(DIAG_FORBIDDEN_FIELD, "forbidden field is not allowed in internal carrier input")
      end

      diags
    end

    def valid_authority?
      authority = @static_data["authority"]
      return false unless authority.is_a?(Hash)

      ACCEPTED_AUTHORITY_KINDS.include?(authority["authority_kind"]) &&
        ACCEPTED_CANON_STATUSES.include?(authority["canon_status"]) &&
        authority["authority_ref"].to_s.strip != ""
    end

    def forbidden_field_count
      count_forbidden_keys(@static_data)
    end

    def count_forbidden_keys(value)
      case value
      when Hash
        value.sum do |key, nested|
          (FORBIDDEN_FIELDS.include?(key.to_s) ? 1 : 0) + count_forbidden_keys(nested)
        end
      when Array
        value.sum { |nested| count_forbidden_keys(nested) }
      else
        0
      end
    end

    def record_packet_build_failure(error)
      return if @packet_build_diagnostics.any? do |existing|
        existing["code"] == DIAG_PACKET_BUILD_FAILED
      end

      @packet_build_diagnostics << diag(DIAG_PACKET_BUILD_FAILED, "#{error.class}: packet build failed")
    end

    def carrier_material
      {
        "kind" => @static_data["kind"],
        "format_version" => @static_data["format_version"],
        "static_data_status" => @static_data["static_data_status"],
        "authority" => @static_data["authority"],
        "profile_candidate" => @static_data["profile_candidate"],
        "pack_descriptor_candidates" => pack_descriptor_candidates,
        "excluded_namespaces" => excluded_namespaces,
        "closed_surface_assertions" => closed_surface_assertions
      }
    end

    def static_data_status_output
      status = @static_data["static_data_status"]
      STATIC_DATA_STATUSES.include?(status) ? status : nil
    end

    def authority_output
      return deep_copy(@static_data["authority"]) if valid_authority?

      { "valid" => false }
    end

    def closed_surface_assertions_output
      return {} unless closed_surface_assertions.is_a?(Hash)
      return {} unless closed_surface_assertions.values.all?(false)

      deep_copy(closed_surface_assertions)
    end

    def pack_descriptor_candidates
      value = @static_data["pack_descriptor_candidates"]
      value.is_a?(Array) ? value : []
    end

    def excluded_namespaces
      value = @static_data["excluded_namespaces"]
      value.is_a?(Array) ? value : []
    end

    def closed_surface_assertions
      value = @static_data["closed_surface_assertions"]
      value.nil? ? {} : value
    end

    def normalize_hash(value)
      return recursive_stringify(value) if value.is_a?(Hash)

      {}
    end

    def recursive_stringify(value)
      case value
      when Hash
        value.to_h { |key, nested| [key.to_s, recursive_stringify(nested)] }
      when Array
        value.map { |nested| recursive_stringify(nested) }
      else
        value
      end
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

    def diag(code, message)
      {
        "code" => code,
        "message" => message
      }
    end
  end
end
