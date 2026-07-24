# frozen_string_literal: true
#
# LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2
#
# Reconciles the canonical executable Option/adjacent Result consumer surface:
#   * preserves stdlib.option.or_else / legacy SIR `or_else`;
#   * publishes collision-free predicate/HOF identities selected statically;
#   * gives Result map/and_then/unwrap_or separate SIR owners;
#   * removes the orphaned, Rust-only stdlib.option.wrap row.
#
# Usage:
#   ruby experiments/option_runtime_carrier_convergence_p2/publish_inventory.rb check
#   ruby experiments/option_runtime_carrier_convergence_p2/publish_inventory.rb update

require "digest"
require "json"

INVENTORY = File.expand_path("../../docs/spec/stdlib-inventory.json", __dir__)
WRAP = "stdlib.option.wrap"
OR_ELSE = "stdlib.option.or_else"
UNWRAP_OR = "stdlib.option.unwrap_or"

def surface_row(
  canonical_name:,
  semantic_ir_name:,
  alias_name:,
  category:,
  type_params:,
  input_signature:,
  output_signature:,
  totality:,
  failure_behavior:,
  examples:,
  compatibility_note:,
  diagnostics: ["OOF-TY0", "OOF-VM-OPTION-CARRIER"]
)
  {
    "canonical_name" => canonical_name,
    "semantic_ir_name" => semantic_ir_name,
    "legacy_sir" => nil,
    "aliases" => [
      {
        "kind" => "source_alias",
        "name" => alias_name
      }
    ],
    "category" => category,
    "lifecycle_status" => "production-implemented",
    "semantic_stability" => "design-locked",
    "lowering_status" => "dual-toolchain",
    "compatibility_status" => "pre-v1-none",
    "fragment_class" => "core",
    "purity" => "pure",
    "deterministic" => true,
    "totality" => totality,
    "type_params" => type_params,
    "input_signature" => input_signature,
    "output_signature" => output_signature,
    "diagnostics" => diagnostics,
    "failure_behavior" => failure_behavior,
    "authority_surface" => "none",
    "proof_lineage" => [
      "LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 — static family selection + nominal carrier"
    ],
    "examples" => examples,
    "compatibility_note" => compatibility_note,
    "owner_surface" => "Ch8 §8.3 / §8.4",
    "entry_digest" => nil
  }
end

UNWRAP_ROW = {
  "canonical_name" => UNWRAP_OR,
  "semantic_ir_name" => "unwrap_or",
  "legacy_sir" => nil,
  "aliases" => [
    {
      "kind" => "source_alias",
      "name" => "unwrap_or"
    }
  ],
  "category" => "option",
  "lifecycle_status" => "production-implemented",
  "semantic_stability" => "design-locked",
  "lowering_status" => "dual-toolchain",
  "compatibility_status" => "pre-v1-none",
  "fragment_class" => "core",
  "purity" => "pure",
  "deterministic" => true,
  "totality" => "total for a well-typed nominal Option",
  "type_params" => ["V"],
  "input_signature" => ["Option[V]", "V"],
  "output_signature" => "V",
  "diagnostics" => ["OOF-VM-OPTION-CARRIER"],
  "failure_behavior" =>
    "Some(v) returns v; None returns the fallback. A non-Option runtime carrier fails closed with " \
    "OOF-VM-OPTION-CARRIER and no payload or complete host object is echoed.",
  "authority_surface" => "none",
  "proof_lineage" => [
    "LANG-SUMTYPE-CONSTRUCT-MATCH-P3 — dual-toolchain source typing",
    "LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 — nominal carrier consumer convergence"
  ],
  "examples" => [
    "unwrap_or(some(42), 0) -> 42",
    "unwrap_or(none(), 0) -> 0"
  ],
  "compatibility_note" =>
    "The Option SIR spelling remains `unwrap_or`; a statically resolved Result subject emits the " \
    "separate `result_unwrap_or` identity. Runtime dispatch never guesses from Record keys.",
  "owner_surface" => "Ch8 §8.3",
  "entry_digest" => nil
}.freeze

OPTION_ROWS = [
  surface_row(
    canonical_name: "stdlib.option.is_some",
    semantic_ir_name: "stdlib.option.is_some",
    alias_name: "is_some",
    category: "option",
    type_params: ["T"],
    input_signature: ["Option[T]"],
    output_signature: "Bool",
    totality: "total for a well-typed nominal Option",
    failure_behavior: "Some(_) returns true; None returns false; any non-Option carrier fails closed.",
    examples: ["is_some(some(1)) -> true"],
    compatibility_note: "Only the nominal Option carrier is inspected; nil/raw values and Record keys are never predicates."
  ),
  surface_row(
    canonical_name: "stdlib.option.is_none",
    semantic_ir_name: "stdlib.option.is_none",
    alias_name: "is_none",
    category: "option",
    type_params: ["T"],
    input_signature: ["Option[T]"],
    output_signature: "Bool",
    totality: "total for a well-typed nominal Option",
    failure_behavior: "None returns true; Some(_) returns false; any non-Option carrier fails closed.",
    examples: ["is_none(none()) -> true"],
    compatibility_note: "Only the nominal Option carrier is inspected; nil/raw values and Record keys are never predicates."
  ),
  surface_row(
    canonical_name: "stdlib.option.map",
    semantic_ir_name: "stdlib.option.map",
    alias_name: "map",
    category: "option",
    type_params: %w[T U],
    input_signature: ["Option[T]", "(T) -> U"],
    output_signature: "Option[U]",
    totality: "total when the lambda is total",
    failure_behavior: "None bypasses the lambda; Some(v) returns Some(fn(v)); wrong carriers fail closed.",
    examples: ["map(some(1), x -> x) -> some(1)"],
    compatibility_note: "The compiler selects Option by static subject type; Collection and Result map have distinct SIR identities."
  ),
  surface_row(
    canonical_name: "stdlib.option.flat_map",
    semantic_ir_name: "stdlib.option.flat_map",
    alias_name: "flat_map",
    category: "option",
    type_params: %w[T U],
    input_signature: ["Option[T]", "(T) -> Option[U]"],
    output_signature: "Option[U]",
    totality: "total when the lambda is total and returns Option[U]",
    failure_behavior: "None bypasses the lambda; Some(v) returns fn(v); wrong input/output carriers fail closed.",
    examples: ["flat_map(some(1), x -> some(x)) -> some(1)"],
    compatibility_note: "Option flat_map is statically distinct from stdlib.collection.flat_map; Result flat_map remains refused."
  ),
  surface_row(
    canonical_name: "stdlib.option.and_then",
    semantic_ir_name: "stdlib.option.and_then",
    alias_name: "and_then",
    category: "option",
    type_params: %w[T U],
    input_signature: ["Option[T]", "(T) -> Option[U]"],
    output_signature: "Option[U]",
    totality: "total when the lambda is total and returns Option[U]",
    failure_behavior: "Exact semantic alias of Option flat_map; wrong input/output carriers fail closed.",
    examples: ["and_then(some(1), x -> some(x)) -> some(1)"],
    compatibility_note: "The source alias is retained, but SIR is collision-free from stdlib.result.and_then."
  )
].freeze

RESULT_ROWS = [
  surface_row(
    canonical_name: "stdlib.result.map",
    semantic_ir_name: "stdlib.result.map",
    alias_name: "map",
    category: "result",
    type_params: %w[T E U],
    input_signature: ["Result[T,E]", "(T) -> U"],
    output_signature: "Result[U,E]",
    totality: "total when the lambda is total",
    failure_behavior: "Ok(v) maps its payload; Err(e) is preserved; no Record-shape dispatch.",
    examples: ["map(ok(1), x -> x) -> ok(1)"],
    compatibility_note: "Ch8 Result map is statically selected and no longer shares a bare runtime owner with Option/Collection.",
    diagnostics: ["OOF-TY0"]
  ),
  surface_row(
    canonical_name: "stdlib.result.and_then",
    semantic_ir_name: "stdlib.result.and_then",
    alias_name: "and_then",
    category: "result",
    type_params: %w[T E U],
    input_signature: ["Result[T,E]", "(T) -> Result[U,E]"],
    output_signature: "Result[U,E]",
    totality: "total when the lambda is total and returns Result[U,E]",
    failure_behavior: "Ok(v) evaluates the lambda; Err(e) is preserved in the same error family.",
    examples: ["and_then(ok(1), x -> ok(x)) -> ok(1)"],
    compatibility_note: "Statically distinct from stdlib.option.and_then; Result flat_map remains refused.",
    diagnostics: ["OOF-TY0"]
  ),
  surface_row(
    canonical_name: "stdlib.result.unwrap_or",
    semantic_ir_name: "result_unwrap_or",
    alias_name: "unwrap_or",
    category: "result",
    type_params: %w[T E],
    input_signature: ["Result[T,E]", "T"],
    output_signature: "T",
    totality: "total for a well-typed Result",
    failure_behavior: "Ok(v) returns v; Err(_) returns the fallback; arbitrary Records are not Result.",
    examples: ["unwrap_or(ok(1), 0) -> 1"],
    compatibility_note: "The compiler emits result_unwrap_or; the Option subject emits unwrap_or.",
    diagnostics: ["OOF-TY0"]
  )
].freeze

PRODUCER_RECONCILIATIONS = {
  "stdlib.map.get" => {
    "failure_behavior" =>
      "Absent key returns nominal None; present key returns nominal Some(v). A missing key is data, " \
      "not OOF-MAP1 and not a runtime error.",
    "examples" => [
      "map_get({a: 1}, \"a\") -> Some(1)",
      "map_get({a: 1}, \"b\") -> None"
    ],
    "compatibility_note" =>
      "Direct bytecode and nested eval-AST use one map reader and return the first_class_v1 carrier; " \
      "no host null or unwrapped payload represents Option."
  },
  "stdlib.collection.first" => {
    "compatibility_note" =>
      "first(Collection[T]) returns nominal Option[T] in direct and nested execution. Empty returns " \
      "None and a present element returns Some(value); sealed Option match and fallback consumers use " \
      "the same carrier."
  },
  "stdlib.collection.last" => {
    "compatibility_note" =>
      "last(Collection[T]) returns nominal Option[T] in direct and nested execution. Empty returns " \
      "None and a present element returns Some(value); sealed Option match and fallback consumers use " \
      "the same carrier."
  },
  "stdlib.collection.at" => {
    "compatibility_note" =>
      "Zero-based total reader. Negative, out-of-range, and empty cases return nominal None; an " \
      "in-range element returns nominal Some(value). Direct/eval-AST and sealed match share the same " \
      "first_class_v1 carrier."
  },
  "stdlib.collection.find" => {
    "failure_behavior" =>
      "No match or an empty collection returns nominal None; the first match returns nominal " \
      "Some(value). Arity, collection, and predicate-shape errors remain compile-time diagnostics.",
    "examples" => [
      "find([1, 2], x -> x > 1) -> Some(2)",
      "find([1, 2], x -> x > 9) -> None"
    ],
    "compatibility_note" =>
      "The predicate must return Bool. Direct and nested HOF execution return the same " \
      "first_class_v1 carrier; no Record or host-null shape selects Option."
  },
  "stdlib.integer.parse_int" => {
    "failure_behavior" =>
      "Total; malformed or overflowing input returns nominal None and a valid base-10 integer returns " \
      "nominal Some(value), never a runtime error.",
    "compatibility_note" =>
      "Base-10 only: one optional leading '-' followed by at least one digit; no leading '+', " \
      "whitespace, or alternate base. Direct/eval-AST return first_class_v1 Some/None. Bare parse_int " \
      "and stdlib.numeric.parse_int resolve to canonical stdlib.integer.parse_int."
  },
  "stdlib.text.decode_delimited" => {
    "compatibility_note" =>
      "Successful decoding returns nominal Some(Collection[Text]); dangling or unknown escape returns " \
      "nominal None. Direct and eval-AST use the same first_class_v1 carrier."
  },
  "stdlib.text.decode_frame" => {
    "compatibility_note" =>
      "FrameDecode is { payload: Text, rest: Text }. A valid frame returns nominal Some(FrameDecode); " \
      "malformed or short input returns nominal None. Direct and eval-AST use the same " \
      "first_class_v1 carrier."
  }
}.freeze

def canonical_json(obj)
  case obj
  when Hash
    "{" + obj.keys.sort.map { |key| "#{canonical_json(key.to_s)}:#{canonical_json(obj[key])}" }.join(",") + "}"
  when Array
    "[" + obj.map { |value| canonical_json(value) }.join(",") + "]"
  else
    JSON.generate(obj)
  end
end

def surface_digest(entries)
  payload = entries
            .sort_by { |entry| entry.fetch("canonical_name") }
            .map { |entry| entry.reject { |key, _| key == "entry_digest" } }
  Digest::SHA256.hexdigest(canonical_json(payload))
end

def reconciled_or_else(row)
  lineage =
    row.fetch("proof_lineage").reject do |item|
      item == "LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 — nominal carrier consumer convergence"
    end
  row.merge(
    "diagnostics" => ["OOF-VM-OPTION-CARRIER"],
    "failure_behavior" =>
      "Some(v) returns v; None returns the fallback. A non-Option runtime carrier fails closed " \
      "with OOF-VM-OPTION-CARRIER.",
    "proof_lineage" => lineage + [
      "LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 — nominal carrier consumer convergence"
    ],
    "compatibility_note" =>
      "The canonical function remains stdlib.option.or_else and the emitted SIR remains bare " \
      "`or_else`, the inventory's sole grandfathered legacy_sir exception. P2 changes only the " \
      "runtime operand law to first_class_v1; a future identity migration remains a separate card."
  )
end

def reconcile_producer(row, fields)
  lineage = row.fetch("proof_lineage", []).reject do |item|
    item.include?("Value::Nil") ||
      item.include?("nullable") ||
      item == "LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 — nominal producer convergence"
  end
  row.merge(
    fields.merge(
      "proof_lineage" => lineage + [
        "LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 — nominal producer convergence"
      ]
    )
  )
end

document = JSON.parse(File.read(INVENTORY, encoding: "UTF-8"))
mode = ARGV.fetch(0, "check")

if mode == "update"
  entries = document.fetch("entries")
  abort "missing #{OR_ELSE}" unless entries.any? { |entry| entry["canonical_name"] == OR_ELSE }

  generated_names =
    [WRAP, UNWRAP_OR] +
    OPTION_ROWS.map { |row| row.fetch("canonical_name") } +
    RESULT_ROWS.map { |row| row.fetch("canonical_name") }
  entries = entries.reject { |entry| generated_names.include?(entry["canonical_name"]) }
  entries.map! do |entry|
    fields = PRODUCER_RECONCILIATIONS[entry["canonical_name"]]
    fields ? reconcile_producer(entry, fields) : entry
  end
  or_else_index = entries.index { |entry| entry["canonical_name"] == OR_ELSE }
  entries[or_else_index] = reconciled_or_else(entries.fetch(or_else_index))
  generated = OPTION_ROWS + [UNWRAP_ROW] + RESULT_ROWS
  generated.sort_by { |row| row.fetch("canonical_name") }.reverse_each do |row|
    entries.insert(or_else_index + 1, JSON.parse(JSON.generate(row)))
  end

  document["entries"] = entries
  previous_note =
    " LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 removes orphaned stdlib.option.wrap, publishes " \
    "the already-live unwrap_or consumer, and binds Option consumers to first_class_v1; digest recomputed."
  current_note =
    " LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 removes stdlib.option.wrap; publishes exact " \
    "Option predicate/HOF/fallback identities and separate Result map/and_then/unwrap_or owners; " \
    "all families are selected statically and the digest is recomputed."
  document["note"] = document.fetch("note").delete_suffix(previous_note).delete_suffix(current_note) + current_note
  document["stdlib_surface_digest"] = surface_digest(entries)
  File.write(INVENTORY, JSON.pretty_generate(document) + "\n")
elsif mode != "check"
  abort "usage: #{$PROGRAM_NAME} [check|update]"
end

entries = JSON.parse(File.read(INVENTORY, encoding: "UTF-8")).fetch("entries")
recorded = JSON.parse(File.read(INVENTORY, encoding: "UTF-8")).fetch("stdlib_surface_digest")
checks = {
  "wrap_removed" => entries.none? { |entry| entry["canonical_name"] == WRAP },
  "or_else_reconciled" => entries.one? { |entry| entry["canonical_name"] == OR_ELSE },
  "unwrap_or_published" => entries.one? { |entry| entry["canonical_name"] == UNWRAP_OR },
  "option_consumers_exact" =>
    OPTION_ROWS.all? do |expected|
      entries.one? do |entry|
        entry["canonical_name"] == expected["canonical_name"] &&
          entry["semantic_ir_name"] == expected["semantic_ir_name"]
      end
    end,
  "result_owners_exact" =>
    RESULT_ROWS.all? do |expected|
      entries.one? do |entry|
        entry["canonical_name"] == expected["canonical_name"] &&
          entry["semantic_ir_name"] == expected["semantic_ir_name"]
      end
    end,
  "option_producers_nominal" =>
    PRODUCER_RECONCILIATIONS.all? do |name, expected_fields|
      row = entries.find { |entry| entry["canonical_name"] == name }
      row &&
        expected_fields.all? { |key, value| row[key] == value } &&
        row.fetch("proof_lineage", []).include?(
          "LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 — nominal producer convergence"
        )
    end,
  "digest_matches" => surface_digest(entries) == recorded
}

checks.each { |name, pass| puts "#{pass ? 'PASS' : 'FAIL'} #{name}" }
abort "inventory reconciliation failed" unless checks.values.all?

puts "entries=#{entries.length}"
puts "stdlib_surface_digest=#{recorded}"
