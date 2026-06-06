# frozen_string_literal: true

require_relative "diagnostics"

module IgniterLang
  module CompilerResult
    module_function

    def ok(format_version:, semantic_ir:, source_path:, report:, igapp_path:, contracts:, runtime_smoke:)
      {
        "kind" => "compiler_result",
        "format_version" => format_version,
        "status" => "ok",
        "program_id" => semantic_ir.fetch("program_id"),
        "source_path" => source_path.to_s,
        "source_hash" => report.fetch("source_hash"),
        "grammar_version" => report.fetch("grammar_version"),
        "stages" => stages(report, assemble: "ok"),
        "igapp_path" => igapp_path.to_s,
        "compilation_report_ref" => report.fetch("program_id"),
        "semantic_ir_ref" => report.fetch("semantic_ir_ref"),
        "contracts" => contracts,
        "diagnostics" => [],
        "warnings" => Diagnostics.warnings(report.fetch("diagnostics", [])),
        "runtime_smoke" => runtime_smoke,
        "report" => report
      }
    end

    def refusal(format_version:, status:, report:, source_path:, report_path:)
      diagnostics = report.fetch("diagnostics", [])
      {
        "kind" => "compiler_result",
        "format_version" => format_version,
        "status" => status,
        "program_id" => report.fetch("semantic_ir_ref", nil),
        "source_path" => source_path.to_s,
        "source_hash" => report.fetch("source_hash", nil),
        "grammar_version" => report.fetch("grammar_version", nil),
        "stages" => stages(report, assemble: "skipped"),
        "igapp_path" => nil,
        "contracts" => [],
        "compilation_report_path" => report_path.to_s,
        "diagnostics" => Diagnostics.errors(diagnostics),
        "warnings" => Diagnostics.warnings(diagnostics),
        "report" => report
      }
    end

    def strict_terminal(format_version:, status:, report:, source_path:, diagnostics:)
      {
        "kind" => "compiler_result",
        "format_version" => format_version,
        "status" => status,
        "program_id" => report.fetch("semantic_ir_ref", nil),
        "source_path" => source_path.to_s,
        "source_hash" => report.fetch("source_hash", nil),
        "grammar_version" => report.fetch("grammar_version", nil),
        "stages" => stages(report, assemble: "skipped"),
        "igapp_path" => nil,
        "contracts" => [],
        "compilation_report_path" => nil,
        "diagnostics" => diagnostics,
        "warnings" => Diagnostics.warnings(report.fetch("diagnostics", [])),
        "report" => report
      }
    end

    def public_result(result)
      result.reject { |key, _value| key == "report" }
    end

    def stages(report, assemble:)
      report.fetch("stages").merge("assemble" => assemble)
    end
  end
end
