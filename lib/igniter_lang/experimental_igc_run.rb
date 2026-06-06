# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "pathname"

module IgniterLang
  module ExperimentalIgcRun
    module_function

    CARD = "S3-R234-C2-I"
    TRACK = "experimental-igc-run-slice0-implementation-v0"
    FORMAT_VERSION = "0.1.0"
    RESULT_KIND = "experimental_igc_run_v0_result"
    RUNTIME_SELECTOR = "delegated-experimental:ivm-proof"
    VM_CANDIDATE_SELECTOR = "delegated-experimental:igniter-vm-candidate"
    RUNTIME_AUTHORITY = "non-canonical / delegated experimental"
    REPO_ROOT = Pathname.new(__dir__).join("../../..").expand_path
    PROOF_RUNTIME_PATH = REPO_ROOT.join(
      "igniter-lang/experiments/runtime_machine_memory_proof/compiled_program.rb"
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
      "not igc run implementation"
    ].freeze
    RESULT_NON_CLAIMS = REQUIRED_NON_CLAIMS.freeze

    class RunFailure < StandardError
      attr_reader :code

      def initialize(code, message)
        @code = code
        super(message)
      end
    end

    def run(argv)
      options = parse_args(argv.dup)
      validate_options!(options)
      passport = load_passport(options.fetch(:passport_path))
      input = load_input(options.fetch(:input_path))
      if vm_candidate?(options)
        require_relative "experimental_igc_run_vm_candidate"

        packet = ExperimentalIgcRunVmCandidate.run(
          options: options,
          passport: passport,
          input: input
        )
        write_packet_object(options.fetch(:out_path), packet)
        return packet.fetch("status") == "ok"
      end

      validate_passport!(passport, options.fetch(:artifact_path))
      outputs = execute_with_delegated_runtime(
        options.fetch(:artifact_path),
        passport.fetch("output_contract").fetch("contract_name"),
        input
      )
      write_packet(options, "ok", outputs, [])
      true
    rescue RunFailure => e
      write_packet(options, "blocked", {}, diagnostic_for(e)) if defined?(options) && options[:out_path]
      warn e.message
      false
    rescue LoadError => e
      failure = RunFailure.new("runtime_loader_error", "#{e.class}: #{e.message}")
      write_packet(options, "error", {}, diagnostic_for(failure)) if defined?(options) && options[:out_path]
      warn failure.message
      false
    rescue => e
      failure = RunFailure.new("run_error", "#{e.class}: #{e.message}")
      write_packet(options, "error", {}, diagnostic_for(failure)) if defined?(options) && options[:out_path]
      warn failure.message
      false
    end

    def parse_args(argv)
      options = { experimental: false }
      options[:artifact_path] = Pathname.new(argv.shift).expand_path if argv.first&.start_with?("-") == false

      until argv.empty?
        flag = argv.shift
        case flag
        when "--passport"
          options[:passport_path] = Pathname.new(required_value!(flag, argv)).expand_path
        when "--input"
          options[:input_path] = Pathname.new(required_value!(flag, argv)).expand_path
        when "--runtime"
          options[:runtime_selector] = required_value!(flag, argv)
        when "--out"
          options[:out_path] = Pathname.new(required_value!(flag, argv)).expand_path
        when "--experimental"
          options[:experimental] = true
        else
          raise RunFailure.new("unsupported_argument", "unsupported argument for igc run: #{flag}")
        end
      end

      options
    end

    def required_value!(flag, argv)
      value = argv.shift
      raise RunFailure.new("missing_value", "#{flag} requires a value") unless value

      value
    end

    def validate_options!(options)
      raise RunFailure.new("missing_artifact", "igc run requires ARTIFACT.igapp") unless options[:artifact_path]
      raise RunFailure.new("missing_experimental", "igc run requires --experimental") unless options[:experimental]
      raise RunFailure.new("missing_passport", "igc run requires --passport PATH.json") unless options[:passport_path]
      raise RunFailure.new("missing_input", "igc run requires --input PATH.json") unless options[:input_path]
      raise RunFailure.new("missing_runtime", "igc run requires --runtime #{RUNTIME_SELECTOR}") unless options[:runtime_selector]
      raise RunFailure.new("missing_out", "igc run requires --out PATH.json") unless options[:out_path]
      unless options.fetch(:artifact_path).to_s.end_with?(".igapp") && options.fetch(:artifact_path).directory?
        raise RunFailure.new("unsupported_artifact", "igc run Slice 0 accepts .igapp directories only")
      end
      unless [RUNTIME_SELECTOR, VM_CANDIDATE_SELECTOR].include?(options.fetch(:runtime_selector))
        raise RunFailure.new("unsupported_runtime", "unsupported runtime selector for experimental igc run")
      end
      raise RunFailure.new("passport_not_found", "passport path not found") unless options.fetch(:passport_path).file?
      raise RunFailure.new("input_not_found", "input path not found") unless options.fetch(:input_path).file?
    end

    def load_passport(path)
      parsed = JSON.parse(path.read)
      raise RunFailure.new("malformed_passport", "passport JSON must be an object") unless parsed.is_a?(Hash)

      parsed
    rescue JSON::ParserError
      raise RunFailure.new("malformed_passport", "passport file must contain valid JSON")
    rescue Errno::EACCES
      raise RunFailure.new("passport_not_readable", "passport path is not readable")
    end

    def load_input(path)
      parsed = JSON.parse(path.read)
      raise RunFailure.new("input_not_object", "input JSON must be an object") unless parsed.is_a?(Hash)

      parsed
    rescue JSON::ParserError
      raise RunFailure.new("malformed_input", "input file must contain valid JSON")
    rescue Errno::EACCES
      raise RunFailure.new("input_not_readable", "input path is not readable")
    end

    def validate_passport!(passport, artifact_path)
      expect_field!(passport, "passport_kind", "artifact_passport")
      expect_field!(passport, "artifact_kind", "igapp_dir")
      expect_field!(passport, "surface_dimension", "executable_runtime")
      expect_field!(passport, "runtime_target_kind", "delegated_experimental_runtime")
      expect_includes!(passport, "authority_status", "non-canonical")
      expect_includes!(passport, "authority_status", "evidence-only")
      validate_non_claims!(passport.fetch("non_claims", nil))
      require_present!(passport, "input_contract")
      require_present!(passport, "failure_policy")
      require_present!(passport, "runtime_implementation_id")
      validate_output_contract!(passport.fetch("output_contract", nil))
      validate_artifact_ref!(passport.fetch("artifact_ref", nil), artifact_path)
      validate_artifact_digest!(passport.fetch("artifact_digest", nil), artifact_path)
    end

    def expect_field!(passport, field, expected)
      actual = passport.fetch(field, nil)
      return if actual == expected

      raise RunFailure.new("invalid_passport_#{field}", "passport #{field} must be #{expected}")
    end

    def expect_includes!(passport, field, expected)
      actual = passport.fetch(field, nil).to_s
      return if actual.include?(expected)

      raise RunFailure.new("invalid_passport_#{field}", "passport #{field} must include #{expected}")
    end

    def require_present!(passport, field)
      value = passport.fetch(field, nil)
      return unless value.nil? || (value.respond_to?(:empty?) && value.empty?)

      raise RunFailure.new("invalid_passport_#{field}", "passport #{field} is required")
    end

    def validate_non_claims!(claims)
      unless claims.is_a?(Array)
        raise RunFailure.new("invalid_passport_non_claims", "passport non_claims must be an array")
      end

      missing = REQUIRED_NON_CLAIMS.reject { |claim| claims.include?(claim) }
      return if missing.empty?

      raise RunFailure.new("invalid_passport_non_claims", "passport non_claims missing #{missing.join(", ")}")
    end

    def validate_output_contract!(contract)
      unless contract.is_a?(Hash)
        raise RunFailure.new("invalid_output_contract", "passport output_contract must be an object")
      end
      if contract.fetch("deferred", false) || contract.to_s.include?("deferred")
        raise RunFailure.new("deferred_output_contract", "passport output_contract must not be deferred")
      end
      name = contract.fetch("contract_name", nil)
      return if name.is_a?(String) && !name.empty?

      raise RunFailure.new("missing_output_contract_name", "passport output_contract.contract_name is required")
    end

    def validate_artifact_ref!(artifact_ref, artifact_path)
      unless artifact_ref.is_a?(String) && !artifact_ref.empty?
        raise RunFailure.new("artifact_ref_mismatch", "passport artifact_ref is required")
      end

      ref_path = Pathname.new(artifact_ref)
      ref_path = REPO_ROOT.join(ref_path) unless ref_path.absolute?
      return if ref_path.expand_path == artifact_path.expand_path

      raise RunFailure.new("artifact_ref_mismatch", "passport artifact_ref does not match artifact path")
    end

    def validate_artifact_digest!(digest, artifact_path)
      expected = directory_digest(artifact_path)
      return if digest == expected

      raise RunFailure.new("artifact_digest_mismatch", "passport artifact_digest does not match artifact path")
    end

    def directory_digest(dir)
      files = dir.glob("**/*").select(&:file?).sort_by { |path| path.relative_path_from(dir).to_s }
      file_digests = files.map { |path| Digest::SHA256.hexdigest(path.binread) }
      "sha256:#{Digest::SHA256.hexdigest(file_digests.join(":"))}"
    end

    def execute_with_delegated_runtime(artifact_path, contract_name, input)
      require PROOF_RUNTIME_PATH.to_s

      program = RuntimeMachineMemoryProof::CompiledProgram.load_igapp(artifact_path)
      program.validate!
      program.evaluate_contract(contract_name, input)
    end

    def write_packet(options, status, outputs, diagnostics)
      packet = result_packet(options, status, outputs, diagnostics)
      if vm_candidate?(options)
        require_relative "experimental_igc_run_vm_candidate"

        packet = ExperimentalIgcRunVmCandidate.failure_packet(options, status, diagnostics)
      end
      write_packet_object(options.fetch(:out_path), packet)
    end

    def write_packet_object(path, packet)
      FileUtils.mkdir_p(path.dirname)
      path.write(JSON.pretty_generate(packet))
    end

    def result_packet(options, status, outputs, diagnostics)
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
        "runtime_authority" => RUNTIME_AUTHORITY,
        "outputs" => outputs,
        "diagnostics" => diagnostics,
        "non_claims" => RESULT_NON_CLAIMS,
        "not_compiler_result" => true,
        "not_compilation_report" => true,
        "not_compatibility_report" => true,
        "not_receipt_sidecar" => true,
        "not_release_evidence" => true,
        "not_public_api_response_contract" => true
      }
    end

    def diagnostic_for(error)
      [{ "code" => error.code, "message" => error.message }]
    end

    def vm_candidate?(options)
      options && options[:runtime_selector] == VM_CANDIDATE_SELECTOR
    end
  end
end
