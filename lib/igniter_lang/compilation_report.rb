# frozen_string_literal: true

require_relative "diagnostics"

module IgniterLang
  module CompilationReport
    module_function

    def parse_failure(format_version:, parsed:, source_path:)
      {
        "kind" => "compilation_report",
        "format_version" => format_version,
        "program_id" => "compilation_report/parse_error",
        "grammar_version" => parsed.fetch("grammar_version"),
        "source_hash" => parsed.fetch("source_hash"),
        "source_path" => source_path.to_s,
        "pass_result" => "error",
        "stages" => {
          "parse" => "error",
          "classify" => "skipped",
          "typecheck" => "skipped",
          "emit" => "skipped"
        },
        "diagnostics" => Diagnostics.from_parse_errors(parsed.fetch("parse_errors")),
        "semantic_ir_ref" => nil
      }
    end

    def runtime_smoke_failure(report:, smoke:, source_path:)
      report.merge(
        "pass_result" => "error",
        "source_path" => source_path.to_s,
        "diagnostics" => report.fetch("diagnostics", []) + Diagnostics.from_runtime_smoke(smoke)
      )
    end

    def internal_error(format_version:, source_path:, rule:, error:)
      {
        "kind" => "compilation_report",
        "format_version" => format_version,
        "program_id" => "compilation_report/#{rule}",
        "grammar_version" => "unknown",
        "source_hash" => nil,
        "source_path" => source_path.to_s,
        "pass_result" => "error",
        "stages" => {
          "parse" => "unknown",
          "classify" => "unknown",
          "typecheck" => "unknown",
          "emit" => "unknown"
        },
        "diagnostics" => internal_error_diagnostics(rule, error),
        "semantic_ir_ref" => nil
      }
    end

    def enrich(report:, parsed:, typed: nil)
      contract_name = parsed.fetch("contracts", []).fetch(0, {}).fetch("name", nil)
      diagnostic_contracts = diagnostic_contracts_for(report.fetch("diagnostics", []), typed)
      report.merge(
        "diagnostics" => report.fetch("diagnostics", []).each_with_index.map do |entry, index|
          Diagnostics.enrich(
            [entry],
            category: diagnostic_category_for(report),
            contract: diagnostic_contracts.fetch(index, nil) || contract_name
          ).first
        end
      )
    end

    def with_compiler_profile_contract_validation(report:, validation:)
      return report unless validation

      report.merge(
        "compiler_profile_contract_validation" => validation.merge("report_only" => true)
      )
    end

    def diagnostic_category_for(report)
      stages = report.fetch("stages", {})
      return "typechecker_oof" if stages.fetch("typecheck", nil) == "oof"
      return "emitter_error" if stages.fetch("emit", nil) == "error"

      "classifier_oof"
    end

    def diagnostic_contracts_for(diagnostics, typed)
      return [] unless typed.is_a?(Hash)

      queues = Hash.new { |hash, key| hash[key] = [] }
      typed.fetch("contracts", []).each do |contract|
        contract_name = contract.fetch("name", nil)
        contract.fetch("type_errors", []).each do |entry|
          queues[diagnostic_key(entry)] << contract_name
        end
      end

      diagnostics.map do |entry|
        queue = queues[diagnostic_key(entry)]
        queue.empty? ? nil : queue.shift
      end
    end

    def diagnostic_key(entry)
      normalized = Diagnostics.stringify_keys(entry)
      [
        normalized.fetch("rule", nil),
        normalized.fetch("message", nil),
        normalized.fetch("node", nil),
        normalized.fetch("line", nil)
      ]
    end

    def internal_error_diagnostics(rule, error)
      return Diagnostics.from_assembler_refusal(error) if rule == "assembler_refused"

      Diagnostics.enrich(
        [
          {
            "rule" => rule,
            "severity" => "error",
            "message" => "#{error.class}: #{error.message}"
          }
        ],
        category: "emitter_error"
      )
    end
  end
end
