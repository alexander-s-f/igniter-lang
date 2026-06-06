# frozen_string_literal: true

require "digest"
require "json"
require "pathname"

module IgniterLang
  module ExperimentalIgcRunVmCandidate
    module_function

    CARD = "S3-R243-C2-I"
    TRACK = "experimental-igc-run-slice1-vm-candidate-implementation-v0"
    FORMAT_VERSION = "0.1.0"
    RESULT_KIND = "experimental_igc_run_slice1_result"
    RUNTIME_SELECTOR = "delegated-experimental:igniter-vm-candidate"
    RUNTIME_IMPLEMENTATION_ID = "igniter.delegated.experimental.vm.rust-tokio.v0"
    RUNTIME_AUTHORITY = "non-canonical / delegated experimental / candidate only"
    SELECTED_AN1_PATH = "Path C fail-closed"
    REPO_ROOT = Pathname.new(__dir__).join("../../..").expand_path
    BINDING_MANIFEST_PATH = REPO_ROOT.join(
      "igniter-lang/experiments/experimental_igc_run_slice1_vm_capability_passport_hardening_v0/out/" \
      "vm_capability_passport_binding_manifest.json"
    )
    CAPABILITY_MATRIX_PATH = REPO_ROOT.join(
      "igniter-lang/experiments/experimental_igc_run_slice1_vm_capability_passport_hardening_v0/out/" \
      "capability_support_gap_matrix.json"
    )
    UNSUPPORTED_MATRIX_PATH = REPO_ROOT.join(
      "igniter-lang/experiments/experimental_igc_run_slice1_vm_capability_passport_hardening_v0/out/" \
      "unsupported_feature_fail_closed_matrix.json"
    )
    REQUIRED_NON_CLAIMS = [
      "not stable API",
      "not production ready",
      "not public runtime support",
      "not Reference Runtime support",
      "not Spark integration",
      "not release evidence",
      "not public performance claim",
      "not compiler passport emission",
      "not RuntimeSmoke productization",
      "not igc run general runtime support",
      "not certified alternative implementation",
      "not portability guarantee"
    ].freeze
    INTEGER_GAP_FEATURES = %w[integer_add stdlib_integer_add].freeze

    class Slice1Failure < StandardError
      attr_reader :code, :details

      def initialize(code, message, details = {})
        @code = code
        @details = details
        super(message)
      end
    end

    def run(options:, passport:, input:)
      binding = load_json(BINDING_MANIFEST_PATH, "binding_manifest")
      capability_matrix = load_json(CAPABILITY_MATRIX_PATH, "capability_matrix")
      unsupported_matrix = load_json(UNSUPPORTED_MATRIX_PATH, "unsupported_matrix")

      validation = validate_boundary!(
        options: options,
        passport: passport,
        input: input,
        binding: binding,
        capability_matrix: capability_matrix,
        unsupported_matrix: unsupported_matrix
      )
      feature_gaps = blocked_feature_gaps(passport, capability_matrix)
      unless feature_gaps.empty?
        diagnostics = feature_gaps.map do |feature|
          diagnostic(
            "unsupported_capability_#{feature}",
            "#{feature} is a recorded Slice 1 VM candidate capability gap under AN-1 Path C",
            {
              "feature" => feature,
              "selected_an1_path" => SELECTED_AN1_PATH,
              "policy" => "fail_closed"
            }
          )
        end
        return result_packet(options, "blocked", {}, diagnostics, validation)
      end

      result_packet(options, "blocked", {}, [
        diagnostic(
          "positive_vm_execution_not_available",
          "no authorized positive Slice 1 VM candidate runtime path exists for this artifact",
          { "policy" => "fail_closed" }
        )
      ], validation)
    rescue Slice1Failure => e
      result_packet(options, "blocked", {}, [diagnostic(e.code, e.message, e.details)])
    end

    def failure_packet(options, status, diagnostics)
      result_packet(options, status, {}, diagnostics)
    end

    def unsupported_feature_diagnostics(features)
      matrix = load_json(UNSUPPORTED_MATRIX_PATH, "unsupported_matrix")
      features.map do |feature|
        entry = matrix.fetch("features").find { |candidate| candidate.fetch("feature") == feature.to_s }
        if entry
          diagnostic(entry.fetch("diagnostic_code"), "#{feature} is unsupported for Slice 1", entry)
        else
          diagnostic("unsupported_feature_#{feature}", "#{feature} is unsupported for Slice 1", {
            "feature" => feature.to_s,
            "policy" => "fail_closed"
          })
        end
      end
    end

    def result_packet(options, status, outputs, diagnostics, validation = {})
      {
        "kind" => RESULT_KIND,
        "format_version" => FORMAT_VERSION,
        "card" => CARD,
        "track" => TRACK,
        "status" => status,
        "experimental" => true,
        "pre_v1" => true,
        "stable_api" => false,
        "artifact_ref" => options[:artifact_path]&.to_s,
        "passport_ref" => options[:passport_path]&.to_s,
        "input_ref" => options[:input_path]&.to_s,
        "runtime_selector" => options[:runtime_selector],
        "runtime_implementation_id" => RUNTIME_IMPLEMENTATION_ID,
        "runtime_authority" => RUNTIME_AUTHORITY,
        "selected_an1_path" => SELECTED_AN1_PATH,
        "capability_check" => validation.fetch("capability_check", "not_evaluated"),
        "passport_check" => validation.fetch("passport_check", "not_evaluated"),
        "binding_check" => validation.fetch("binding_check", "not_evaluated"),
        "outputs" => outputs,
        "diagnostics" => diagnostics,
        "non_claims" => REQUIRED_NON_CLAIMS,
        "not_compiler_result" => true,
        "not_compilation_report" => true,
        "not_release_evidence" => true,
        "not_public_api_response_contract" => true,
        "not_runtime_smoke" => true,
        "not_compiler_passport_emission" => true
      }
    end

    def validate_boundary!(options:, passport:, input:, binding:, capability_matrix:, unsupported_matrix:)
      validate_binding!(binding)
      validate_capability_matrix!(capability_matrix)
      validate_unsupported_matrix!(unsupported_matrix)
      validate_input!(input)
      validate_passport_shape!(passport)
      validate_artifact!(options.fetch(:artifact_path), binding)
      {
        "binding_check" => "ok",
        "capability_check" => "ok",
        "passport_check" => passport_check(passport)
      }
    end

    def validate_binding!(binding)
      expect_field!(binding, "kind", "experimental_igc_run_slice1_vm_capability_passport_binding_manifest")
      expect_field!(binding, "artifact_kind", "igapp_dir")
      expect_field!(binding, "runtime_target_kind", "delegated_experimental_runtime")
      expect_field!(binding, "runtime_selector", RUNTIME_SELECTOR)
      expect_field!(binding, "runtime_implementation_id", RUNTIME_IMPLEMENTATION_ID)
      expect_field!(binding, "compiler_passport_emission", false)
      expect_field!(binding, "runtime_smoke_invoked", false)
      expect_field!(binding, "igbin_execution", false)
      require_present!(binding, "artifact_ref")
      require_present!(binding, "artifact_digest")
      require_present!(binding, "required_capabilities")
    end

    def validate_capability_matrix!(matrix)
      expect_field!(matrix, "runtime_implementation_id", RUNTIME_IMPLEMENTATION_ID)
      require_present!(matrix, "capability_source_map")
      require_present!(matrix, "feature_gap_matrix")
    end

    def validate_unsupported_matrix!(matrix)
      require_present!(matrix, "features")
      unless matrix.fetch("features").all? { |entry| entry.fetch("policy", nil) == "fail_closed" }
        raise Slice1Failure.new("unsupported_matrix_not_fail_closed", "unsupported feature matrix must be fail-closed")
      end
    end

    def validate_input!(input)
      return if input.is_a?(Hash)

      raise Slice1Failure.new("input_not_object", "input JSON must be an object")
    end

    def validate_passport_shape!(passport)
      expect_field!(passport, "passport_kind", "artifact_passport")
      expect_field!(passport, "artifact_kind", "igapp_dir")
      expect_field!(passport, "surface_dimension", "executable_runtime")
      expect_field!(passport, "runtime_target_kind", "delegated_experimental_runtime")
      require_present!(passport, "runtime_implementation_id")
      require_present!(passport, "feature_set")
      require_present!(passport, "input_contract")
      require_present!(passport, "output_contract")
      require_present!(passport, "failure_policy")
    end

    def validate_artifact!(artifact_path, binding)
      binding_ref = binding.fetch("artifact_ref")
      ref_path = Pathname.new(binding_ref)
      ref_path = REPO_ROOT.join(ref_path) unless ref_path.absolute?
      unless ref_path.expand_path == artifact_path.expand_path
        raise Slice1Failure.new("binding_artifact_ref_mismatch", "binding artifact_ref does not match artifact path")
      end

      digest = directory_digest(artifact_path)
      return if digest == binding.fetch("artifact_digest")

      raise Slice1Failure.new("binding_artifact_digest_mismatch", "binding artifact_digest does not match artifact path")
    end

    def passport_check(passport)
      if passport.fetch("runtime_implementation_id", nil) == RUNTIME_IMPLEMENTATION_ID
        "runtime_implementation_id_matches_binding"
      else
        "runtime_implementation_id_mismatch_acknowledged"
      end
    end

    def blocked_feature_gaps(passport, capability_matrix)
      features = Array(passport["feature_set"])
      gap_features = capability_matrix.fetch("feature_gap_matrix").select do |entry|
        entry.fetch("slice1_status").to_s.start_with?("gap_fail_closed")
      end.map { |entry| entry.fetch("feature") }
      features & gap_features & INTEGER_GAP_FEATURES
    end

    def expect_field!(object, field, expected)
      return if object.fetch(field, nil) == expected

      raise Slice1Failure.new("invalid_#{field}", "#{field} must be #{expected.inspect}")
    end

    def require_present!(object, field)
      value = object.fetch(field, nil)
      return unless value.nil? || (value.respond_to?(:empty?) && value.empty?)

      raise Slice1Failure.new("missing_#{field}", "#{field} is required")
    end

    def diagnostic(code, message, details = {})
      {
        "code" => code,
        "message" => message,
        "details" => details
      }
    end

    def load_json(path, label)
      JSON.parse(path.read)
    rescue Errno::ENOENT
      raise Slice1Failure.new("missing_#{label}", "#{label} not found")
    rescue JSON::ParserError
      raise Slice1Failure.new("malformed_#{label}", "#{label} must contain valid JSON")
    end

    def directory_digest(dir)
      files = dir.glob("**/*").select(&:file?).sort_by { |path| path.relative_path_from(dir).to_s }
      file_digests = files.map { |path| Digest::SHA256.hexdigest(path.binread) }
      "sha256:#{Digest::SHA256.hexdigest(file_digests.join(":"))}"
    end
  end
end
