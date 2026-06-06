# frozen_string_literal: true

module IgniterLang
  module Diagnostics
    CATEGORIES = {
      parse_error: "parser_error",
      parse_warning: "parser_warning",
      classified: "classifier_oof",
      typechecked: "typechecker_oof",
      assembler: "assembler_refusal",
      runtime_smoke: "runtime_smoke_failure"
    }.freeze

    module_function

    def enrich(entries, category:, contract: nil)
      Array(entries).map do |entry|
        normalized = stringify_keys(entry)
        diagnostic_contract = normalized.key?("contract") ? normalized.fetch("contract") : contract
        node = normalized.fetch("node", nil)
        path = normalized.fetch("path", nil) || path_for(diagnostic_contract, node, normalized)
        span = span_for(normalized)

        normalized.merge(
          "category" => normalized.fetch("category", category),
          "rule" => normalized.fetch("rule", "UNKNOWN"),
          "severity" => normalized.fetch("severity", "error"),
          "message" => normalized.fetch("message", "compiler diagnostic"),
          "contract" => diagnostic_contract,
          "node" => node,
          "path" => path,
          "span" => span
        ).reject { |key, _value| key == "line" || key == "col" }
      end
    end

    def from_parse_errors(errors)
      Array(errors).flat_map do |entry|
        severity = stringify_keys(entry).fetch("severity", "error")
        category = severity == "warning" ? CATEGORIES.fetch(:parse_warning) : CATEGORIES.fetch(:parse_error)
        enrich([entry], category: category)
      end
    end

    def from_classified(diagnostics, contract: nil)
      enrich(diagnostics, category: CATEGORIES.fetch(:classified), contract: contract)
    end

    def from_typechecked(diagnostics, contract: nil)
      enrich(diagnostics, category: CATEGORIES.fetch(:typechecked), contract: contract)
    end

    def from_assembler_refusal(refusal)
      enrich(
        [
          {
            "rule" => "ASSEMBLER-REFUSAL",
            "severity" => "error",
            "message" => refusal.respond_to?(:message) ? refusal.message : refusal.to_s
          }
        ],
        category: CATEGORIES.fetch(:assembler)
      )
    end

    def from_runtime_smoke(smoke)
      return [] if smoke.fetch("trusted", false)

      enrich(
        [
          {
            "rule" => "OOF-RUNTIME-SMOKE",
            "severity" => "error",
            "message" => "RuntimeMachine load/evaluate smoke failed",
            "details" => smoke
          }
        ],
        category: CATEGORIES.fetch(:runtime_smoke)
      )
    end

    def warnings(entries)
      Array(entries).select { |entry| entry.fetch("severity", nil) == "warning" }
    end

    def errors(entries)
      Array(entries).reject { |entry| entry.fetch("severity", nil) == "warning" }
    end

    def stringify_keys(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, entry), out| out[key.to_s] = stringify_keys(entry) }
      when Array
        value.map { |entry| stringify_keys(entry) }
      else
        value
      end
    end

    def path_for(contract, node, entry)
      return nil unless contract || node

      parts = []
      parts << "contract:#{contract}" if contract
      parts << "#{node_kind(entry)}:#{node}" if node
      parts.join("/")
    end

    def node_kind(entry)
      entry.fetch("node_kind", nil) || entry.fetch("kind", nil) || "node"
    end

    def span_for(entry)
      span = entry.fetch("span", nil)
      return span if span.is_a?(Hash)

      line = entry.fetch("line", nil)
      col = entry.fetch("col", nil) || entry.fetch("column", nil)
      return nil unless line && col

      { "line" => line, "col" => col }
    end
  end
end
