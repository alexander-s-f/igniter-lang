# frozen_string_literal: true

module IgniterLang
  module RuntimeSmoke
    begin
      require_relative "../../experiments/runtime_machine_memory_proof/compiled_program"
      PROOF_LOAD_ERROR = nil
    rescue LoadError => e
      PROOF_LOAD_ERROR = e
    end

    DEFAULT_AS_OF = defined?(RuntimeMachineMemoryProof::PROOF_AS_OF) ? RuntimeMachineMemoryProof::PROOF_AS_OF : nil
    DEFAULT_MACHINE_ID = "runtime-machine/production-compiler-cli"
    DEFAULT_SESSION_ID = "session/production-compiler-cli"
    DEFAULT_RULE_VERSION = "production-compiler-cli-wrapper-v0"

    module_function

    def run(out_path:, sample_input:, as_of: DEFAULT_AS_OF, machine_id: DEFAULT_MACHINE_ID,
            session_id: DEFAULT_SESSION_ID, rule_version: DEFAULT_RULE_VERSION)
      ensure_available!
      program = RuntimeMachineMemoryProof::CompiledProgram.load_igapp(out_path)
      program.validate!
      contract_id = program.contracts.keys.fetch(0)
      backend = RuntimeMachineMemoryProof::MemoryTBackend.new
      machine = RuntimeMachineMemoryProof::RuntimeMachine.new(
        machine_id: machine_id,
        session_id: session_id,
        backend: backend
      )
      machine.boot
      load = machine.load_program(program)
      evaluation = machine.evaluate_program(contract_id, eval_input_for(contract_id, sample_input), as_of: as_of)
      checkpoint = machine.checkpoint(horizon: { as_of: as_of, rule_version: rule_version })
      resume = machine.resume(image: checkpoint.fetch(:semantic_image), requested_as_of: as_of)

      {
        "load_status" => load.fetch(:status),
        "contract_id" => contract_id,
        "evaluate_status" => evaluation.fetch(:status),
        "outputs" => evaluation.fetch(:outputs),
        "compatibility_report_status" => resume.fetch(:status),
        "trusted" => load.fetch(:status) == "loaded" &&
          evaluation.fetch(:status) == "ok" &&
          resume.fetch(:status) == "trusted"
      }
    rescue => e
      {
        "load_status" => "blocked",
        "error" => "#{e.class}: #{e.message}",
        "trusted" => false
      }
    end

    def callback(**options)
      lambda do |out_path:, sample_input:|
        run(out_path: out_path, sample_input: sample_input, **options)
      end
    end

    def eval_input_for(contract_id, sample_input)
      return { "a" => 19, "b" => 23 } if contract_id == "Add"

      sample_input
    end

    def available?
      defined?(RuntimeMachineMemoryProof::CompiledProgram) &&
        defined?(RuntimeMachineMemoryProof::RuntimeMachine)
    end

    def ensure_available!
      return if available?

      message = "IgniterLang::RuntimeSmoke is proof-backed; runtime_machine_memory_proof is unavailable in this package context"
      message = "#{message}: #{PROOF_LOAD_ERROR.message}" if PROOF_LOAD_ERROR
      raise LoadError, message
    end
  end
end
