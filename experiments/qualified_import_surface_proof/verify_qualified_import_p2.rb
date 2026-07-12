#!/usr/bin/env ruby
# LANG-STDLIB-INVENTORY-QUALIFIED-IMPORT-SURFACE-P2 — Ruby half of the qualified-only import gate.
#
# Locks the canon-side contract symmetrically with igniter-lab's
# `inventory_qualified_import_tests.rs`:
#   * `import stdlib.bytes.{length}`        -> OOF-IMP3 (qualified_only name is never importable)
#   * `import stdlib.bytes.{text_to_bytes}` -> OOF-IMP3 (compat alias is not importable either)
#   * `import stdlib.collection.{sort_by}`  -> clean    (bare_alias rows keep importing, no churn)
#   * `import stdlib.bytes` (module known)  -> no OOF-IMP2 (the module exists; names are gated)
#   * qualified CALL typing stays green     -> covered by the P7 parity proofs (typechecker), cited
#
# Run: ruby experiments/qualified_import_surface_proof/verify_qualified_import_p2.rb
# NOTE: experiments/ is gitignored — `git add -f` this file when committing the card.

require_relative "../../lib/igniter_lang/multifile_resolver"
require "json"

PASS = []
FAIL = []
def check(label)
  ok = yield
  (ok ? PASS : FAIL) << label
  puts format("%-72s %s", label, ok ? "PASS" : "FAIL")
rescue => e
  FAIL << label
  puts format("%-72s FAIL (%s)", label, e.message)
end

resolver = IgniterLang::MultifileResolver.new

def diags_for(resolver, import_path, names)
  import = { "module_path" => import_path }
  import["names"] = names if names
  resolver.send(
    :stdlib_import_diagnostics,
    import,
    module_path: "ProofModule",
    source_path: "proof.ig"
  )
end

check("import stdlib.bytes.{length} -> OOF-IMP3") do
  d = diags_for(resolver, "stdlib.bytes", ["length"])
  d.length == 1 && d[0]["rule"] == "OOF-IMP3"
end

check("import stdlib.bytes.{text_to_bytes} (compat alias) -> OOF-IMP3") do
  d = diags_for(resolver, "stdlib.bytes", ["text_to_bytes"])
  d.length == 1 && d[0]["rule"] == "OOF-IMP3"
end

check("import stdlib.bytes (module itself known, no OOF-IMP2)") do
  diags_for(resolver, "stdlib.bytes", nil).empty?
end

check("import stdlib.collection.{sort_by, map} stays clean (bare_alias, no churn)") do
  diags_for(resolver, "stdlib.collection", %w[sort_by map]).empty?
end

check("import stdlib.collection.{no_such_op} still OOF-IMP3 (gate unchanged)") do
  d = diags_for(resolver, "stdlib.collection", ["no_such_op"])
  d.length == 1 && d[0]["rule"] == "OOF-IMP3"
end

check("import stdlib.nosuchmodule -> OOF-IMP2 (unknown module unchanged)") do
  d = diags_for(resolver, "stdlib.nosuchmodule", nil)
  d.length == 1 && d[0]["rule"] == "OOF-IMP2"
end

check("inventory: exactly 13 qualified_only rows, all stdlib.bytes.*") do
  inv = JSON.parse(File.read(File.expand_path("../../docs/spec/stdlib-inventory.json", __dir__), encoding: "utf-8"))
  qo = inv.fetch("entries").select { |e| e["import_surface"] == "qualified_only" }
  qo.length == 13 && qo.all? { |e| e["canonical_name"].start_with?("stdlib.bytes.") }
end

puts "-" * 80
puts "PASS #{PASS.length} / FAIL #{FAIL.length}"
exit(FAIL.empty? ? 0 : 1)
