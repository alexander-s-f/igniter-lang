# frozen_string_literal: true
#
# LANG-STDLIB-CONTENT-DIGEST-P1 — publish the single `stdlib.bytes.sha256` inventory row.
#
#   ruby experiments/stdlib_content_digest_proof/inventory_publish_sha256.rb check
#   ruby experiments/stdlib_content_digest_proof/inventory_publish_sha256.rb update
#
# Digest recipe (unchanged, and deliberately recomputed here rather than copied):
#   sha256(canonical_json(entries.sort_by(canonical_name).map(reject entry_digest)))
# with key-sorted compact JSON. The file itself is written with JSON.pretty_generate so it
# round-trips byte-identically.

require "json"
require "digest"

INVENTORY = File.expand_path("../../docs/spec/stdlib-inventory.json", __dir__)
NAME      = "stdlib.bytes.sha256"

ROW = {
  "canonical_name" => NAME,
  "semantic_ir_name" => NAME,
  "legacy_sir" => nil,
  "aliases" => [],
  "category" => "bytes",
  "lifecycle_status" => "production-implemented",
  "semantic_stability" => "design-locked",
  "lowering_status" => "dual-toolchain",
  "compatibility_status" => "pre-v1-none",
  "fragment_class" => "core",
  "purity" => "pure",
  "deterministic" => true,
  "totality" => "total",
  "type_params" => [],
  "input_signature" => ["Bytes"],
  "output_signature" => "Text",
  "diagnostics" => %w[OOF-TM1 OOF-TY0 OOF-BY1],
  "failure_behavior" =>
    "arity OOF-TM1; non-Bytes argument OOF-TY0 at typecheck; TOTAL at runtime — every Bytes " \
    "value, including empty, yields exactly 64 lower-case hex digits",
  "authority_surface" => "none",
  "import_surface" => "qualified_only",
  "proof_lineage" => [
    "LANG-STDLIB-BYTES-CANON-ADMISSION-P7 — the qualified Bytes algebra this operation extends",
    "LANG-STDLIB-BYTES-HEX-CODEC-P1 — canonical lower-case hex rendering precedent",
    "LANG-STDLIB-CONTENT-DIGEST-P1 — Ch8 §8.11.2 normative signature, Ruby/Rust typing+SIR " \
    "parity, shared VM helper (bytecode + eval_ast/HOF byte-identical), NIST empty and \"abc\" " \
    "vectors pinned"
  ],
  "examples" => [
    "stdlib.bytes.sha256(stdlib.bytes.from_text(\"\")) -> " \
    "\"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\"",
    "stdlib.bytes.sha256(stdlib.bytes.from_text(\"abc\")) -> " \
    "\"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad\""
  ],
  "compatibility_note" =>
    "Qualified-only module surface (Ch8 §8.11.6): callable ONLY as the qualified name; " \
    "bare/named import is refused (OOF-IMP3); no compat alias. Carrier-invariant — digests the " \
    "octets without exposing the internal representation. The result carries NO `sha256:` " \
    "prefix: the caller owns framing, so a receipt needing `sha256:<64-lower-hex>` builds that " \
    "text itself. This is a content-address, NOT authentication, authorization, a MAC, a " \
    "signature, password hashing or canonical JSON hashing, and it is not evidence that the " \
    "digested content is true, trusted, admitted or authorized.",
  "owner_surface" => "Ch8 §8.11",
  "entry_digest" => nil
}.freeze

def canonical_json(obj)
  case obj
  when Hash  then "{" + obj.keys.sort.map { |k| "#{canonical_json(k.to_s)}:#{canonical_json(obj[k])}" }.join(",") + "}"
  when Array then "[" + obj.map { |v| canonical_json(v) }.join(",") + "]"
  else JSON.generate(obj)
  end
end

def surface_digest(entries)
  payload = entries
            .sort_by { |e| e["canonical_name"] }
            .map { |e| e.reject { |k, _| k == "entry_digest" } }
  Digest::SHA256.hexdigest(canonical_json(payload))
end

doc = JSON.parse(File.read(INVENTORY, encoding: "UTF-8"))
entries = doc.fetch("entries")
mode = ARGV[0] || "check"

existing = entries.find { |e| e["canonical_name"] == NAME }
puts "before: #{entries.size} entries, digest #{doc['stdlib_surface_digest']}"
puts "row already present: #{!existing.nil?}"

case mode
when "check"
  puts "recomputed digest of CURRENT file: #{surface_digest(entries)}"
  puts "matches recorded: #{surface_digest(entries) == doc['stdlib_surface_digest']}"
when "update"
  abort "refusing to publish twice — row already present" if existing

  entries << JSON.parse(JSON.generate(ROW))
  doc["entries"] = entries
  new_digest = surface_digest(entries)
  doc["stdlib_surface_digest"] = new_digest
  File.write(INVENTORY, JSON.pretty_generate(doc) + "\n")
  puts "after:  #{entries.size} entries, digest #{new_digest}"
else
  abort "usage: #{$PROGRAM_NAME} [check|update]"
end
