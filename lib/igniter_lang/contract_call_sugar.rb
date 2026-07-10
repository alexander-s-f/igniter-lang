# frozen_string_literal: true

module IgniterLang
  # LANG-CONTRACT-CALL-SUGAR-P6 (canon parity with igniter-compiler/src/call_sugar.rs).
  #
  # Pure DX sugar for calling a visible contract by name:
  #
  #     import IgBeat.Sequencer.{ RenderTrack }
  #     compute samples = RenderTrack(track, steps)
  #
  # desugars, BEFORE classify, into the existing static contract call:
  #
  #     compute samples = call_contract("RenderTrack", track, steps)
  #
  # A parse-tree rewrite: no node of a new kind reaches classify/typecheck/emit, so the SIR is
  # identical to a hand-written call_contract. Visibility, short-name ambiguity, and the pure-only
  # effect boundary are all inherited from the call_contract resolver.
  #
  # Precedence (card Q1): the rewrite is the FALLBACK — it fires ONLY when the call name is a
  # declared contract AND is NOT a user `def` (def wins) AND is NOT a reserved/sugar builtin.
  module ContractCallSugar
    RESERVED = %w[call_contract invoke recur ok err some none].freeze

    module_function

    # Mutates `parsed` (a Hash) in place. Returns it.
    def lower!(parsed)
      return parsed unless parsed.is_a?(Hash)

      contract_names = Array(parsed["contracts"]).map { |c| c["name"] }.compact.to_set
      return parsed if contract_names.empty?

      def_names = Array(parsed["functions"]).map { |f| f["name"] }.compact.to_set
      rewrite(parsed, contract_names, def_names)
      parsed
    end

    def rewrite(node, contract_names, def_names)
      case node
      when Array
        node.each { |v| rewrite(v, contract_names, def_names) }
      when Hash
        node.each_value { |v| rewrite(v, contract_names, def_names) }
        if node["kind"] == "call"
          name = node["fn"]
          if name.is_a?(String) &&
             contract_names.include?(name) &&
             !def_names.include?(name) &&
             !RESERVED.include?(name)
            args = node["args"].is_a?(Array) ? node["args"] : []
            node["fn"] = "call_contract"
            node["args"] = [{ "kind" => "literal", "value" => name, "type_tag" => "String" }] + args
          end
        end
      end
    end
  end
end
