# frozen_string_literal: true

# Fragment Registry Compatibility Adapter — internal direct-require-only helper.
#
# ISOLATION CONTRACT — this file must not:
#   - be required from lib/igniter_lang.rb (direct-require-only; no root require)
#   - be wired into the live classifier (classifier_wiring_authorized: false)
#   - participate in live classifier dispatch (held_live_dispatch: true)
#   - return results that become a ClassifiedProgram field, compiler input,
#     report output, CLI/API output, or artifact metadata
#   - touch parser, TypeChecker, SemanticIR, assembler, report, .igapp,
#     runtime, Spark, or production behavior
#
# Authorized by: S3-R147-C1-A
# Track: fragment-registry-compatibility-adapter-helper-implementation-proof-v0
#
# Selection rules (R146 proof selection order, pinned exact):
#   if oof present      → oof
#   elsif temporal      → temporal
#   elsif escape        → escape
#   elsif stream        → escape   (stream maps to escape)
#   elsif epistemic     → epistemic
#   else                → core
#
# API (exact R146 C1 shape; no field-name or result-structure change without
# a separate explicit delta review):
#   IgniterLang::FragmentRegistryCompatibilityAdapter.project(input_hash) -> result_hash

module IgniterLang
  class FragmentRegistryCompatibilityAdapter
    FORMAT_VERSION = "0.1.0".freeze
    KIND_INPUT     = "fragment_registry_compatibility_adapter_helper_input".freeze
    KIND_RESULT    = "fragment_registry_compatibility_adapter_helper_result".freeze

    # R146 proof selection rules in priority order.
    # Must match the proof helper_result_shape.json rules_in_order exactly.
    SELECTION_RULES = [
      { presence: "oof",       selected: "oof"       },
      { presence: "temporal",  selected: "temporal"  },
      { presence: "escape",    selected: "escape"    },
      { presence: "stream",    selected: "escape"    }, # stream → escape (not a direct fragment)
      { presence: "epistemic", selected: "epistemic" }
    ].freeze

    DEFAULT_SELECTED = "core".freeze

    # Project fragment registry compatibility from an internal input hash.
    #
    # Input hash shape (kind: fragment_registry_compatibility_adapter_helper_input):
    #   contracts[]               — array of { contract_ref, declaration_fragment_presence,
    #                               current_selected_fragment }
    #   guarded_non_fragments[]   — array of { name, classification_kind, selected_fragment }
    #   oof_projection_policy     — { primary_semantics, blocked, loadable, capability }
    #   classifier_wiring_authorized — false (must remain false)
    #   source_r144               — { matrix_digest, ... }
    #
    # @param input_hash [Hash] Internal helper input conforming to R146 C1 shape.
    # @return [Hash] Internal result conforming to R146 C1 result shape.
    #   NEVER touches classifier state, reports, public surfaces, or artifacts.
    def self.project(input_hash)
      contracts             = Array(input_hash["contracts"])
      guarded_non_fragments = Array(input_hash["guarded_non_fragments"])
      oof_projection_policy = input_hash.fetch("oof_projection_policy", {})

      r144_source_digest = input_hash.dig("source_r144", "matrix_digest")
      r144_source_status = input_hash.dig("source_r144", "source_status") || "PASS"

      rows = contracts.map do |contract|
        ref      = contract["contract_ref"]
        presence = Array(contract["declaration_fragment_presence"])
        current  = contract["current_selected_fragment"]
        selected = select_fragment(presence)
        parity   = selected == current ? "PASS" : "MISMATCH"

        {
          "contract_ref"                  => ref,
          "declaration_fragment_presence" => presence,
          "current_selected_fragment"     => current,
          "selected_fragment"             => selected,
          "parity"                        => parity
        }
      end

      mismatches    = rows.select { |r| r["parity"] == "MISMATCH" }
      r144_preserved = mismatches.empty?

      {
        "kind"           => KIND_RESULT,
        "format_version" => FORMAT_VERSION,
        "selected_fragment_projection" => {
          "rows"           => rows,
          "mismatches"     => mismatches,
          "rules_in_order" => rules_in_order_description
        },
        "guarded_non_fragments"        => guarded_non_fragments,
        "oof_projection_policy"        => oof_projection_policy,
        "r144_parity" => {
          "preserved"     => r144_preserved,
          "source_digest" => r144_source_digest,
          "source_status" => r144_source_status
        },
        "held_live_dispatch"            => true,
        "classifier_wiring_authorized"  => false
      }
    end

    # -------------------------------------------------------------------------
    # Private class-level helpers
    # -------------------------------------------------------------------------

    # Select the fragment name for the given list of declared fragment presences,
    # applying the R146 proof selection rules in priority order.
    def self.select_fragment(presence_list)
      SELECTION_RULES.each do |rule|
        return rule[:selected] if presence_list.include?(rule[:presence])
      end
      DEFAULT_SELECTED
    end
    private_class_method :select_fragment

    # Produce the canonical rules_in_order array for inclusion in the result shape.
    def self.rules_in_order_description
      SELECTION_RULES.map do |rule|
        { "if" => "#{rule[:presence]} present", "selected" => rule[:selected] }
      end + [{ "otherwise" => DEFAULT_SELECTED }]
    end
    private_class_method :rules_in_order_description
  end
end
