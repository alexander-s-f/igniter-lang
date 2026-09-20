#!/usr/bin/env ruby
# frozen_string_literal: true

# LANG-CALLABLE-COMPATIBILITY-AND-BINDER-PROOF-REPAIR-R12 — Canon focused proof (private candidate).
#
# The typechecker's ref arm reports OOF-P1 for a MISSING declaration, not for missing evidence:
#   A. a lambda parameter bound over the empty literal (`fold([], 0, (a, v) -> …)`) is admitted in a
#      stream callable and on the ordinary route; its ordering keeps the permissive ordinary identity
#      `stdlib.integer.gt` (no invented numeric type); negation likewise `stdlib.integer.neg`;
#   B. an UNDECLARED name inside the same lambda still refuses OOF-P1 "Unresolved symbol: w";
#   C. a structurally ambiguous nested record-literal seed with no record hint refuses OOF-TY0
#      (canon's ambiguity law, unchanged);
#   D. the R11 mandatory nested Float case still selects `stdlib.float.gt` (regression guard).

require "json"
require "fileutils"
require "pathname"
require "tmpdir"

HERE = Pathname.new(__FILE__).expand_path.dirname
ROOT = HERE.join("../..").expand_path
LIB = ROOT.join("lib").to_s
$LOAD_PATH.unshift(LIB) unless $LOAD_PATH.include?(LIB)
require "igniter_lang"

FIXTURES = HERE.join("fixtures")
$pass = 0
$fail = 0

def check(name, ok, detail = "")
  if ok
    $pass += 1
    puts "PASS #{name}"
  else
    $fail += 1
    puts "FAIL #{name} #{detail}"
  end
end

def compile(fixture)
  Dir.mktmpdir("r12canon") do |dir|
    out = File.join(dir, "out.igapp")
    result = IgniterLang::CompilerOrchestrator.new.compile_sources(source_paths: [FIXTURES.join(fixture).to_s], out_path: out)
    diags = result.dig("compilation_report", "diagnostics") || result["diagnostics"] || []
    sir_path = File.join(out, "semantic_ir_program.json")
    sir = File.exist?(sir_path) ? JSON.parse(File.read(sir_path)) : nil
    [result["status"], diags.map { |d| d["rule"] }.uniq.sort, diags.map { |d| d["message"] }, sir]
  end
end

def identities(sir)
  JSON.pretty_generate(sir.fetch("callables", {})).scan(/"fn": "([^"]+)"/).flatten
      .select { |f| f.start_with?("stdlib.integer.", "stdlib.float.", "stdlib.decimal.", "user.") }.sort
end

# A. empty carrier: bound-but-unknown element
status, rules, _msgs, sir = compile("e1_empty_carrier_s.ig")
check("A1 e1 stream admitted (was OOF-P1 'Unresolved symbol: v')", status == "ok", rules.inspect)
check("A2 e1 stream keeps the permissive integer identity, no invented Float", sir && identities(sir) == ["stdlib.integer.gt"], sir ? identities(sir).inspect : "no sir")
status, rules, _msgs, _sir = compile("e1_empty_carrier_f.ig")
check("A3 e1 ordinary route admitted", status == "ok", rules.inspect)
status, rules, _msgs, sir = compile("r12_empty_carrier_neg.ig")
check("A4 empty carrier with negation admitted with integer identities", status == "ok" && sir && identities(sir) == ["stdlib.integer.gt", "stdlib.integer.neg"], "#{status} #{rules.inspect} #{sir ? identities(sir).inspect : ''}")

# B. undeclared name still refuses
status, rules, msgs, _sir = compile("r12_unbound_name.ig")
check("B1 undeclared name refuses OOF-P1", status != "ok" && rules.include?("OOF-P1") && msgs.any? { |m| m.include?("Unresolved symbol: w") }, "#{status} #{rules.inspect} #{msgs.first(2).inspect}")

# C. structural ambiguity (no hint) still refuses OOF-TY0
status, rules, msgs, _sir = compile("r12_record_seed_ambiguous.ig")
check("C1 ambiguous nested record seed refuses OOF-TY0", status != "ok" && rules.include?("OOF-TY0") && msgs.any? { |m| m.include?("Ambiguous record literal type") }, "#{status} #{rules.inspect}")

# E. review F-07: an empty fold returning its bound-but-unknown element is ADMITTED by canon (declared asymmetry with Rust, which refuses OOF-COL4)
status, rules, _msgs, _sir = compile("r12_empty_fold_returns_element.ig")
check("E1 empty fold returning the element admitted on canon (Rust refuses OOF-COL4: declared asymmetry)", status == "ok", rules.inspect)

# D. regression guard
status, _rules, _msgs, sir = compile("s3_nested_float_param_ordering.ig")
check("D1 mandatory nested Float case still selects stdlib.float.gt", status == "ok" && sir && identities(sir) == ["stdlib.float.gt"], sir ? identities(sir).inspect : status)

puts "#{$pass} PASS / #{$fail} FAIL"
exit($fail.zero? ? 0 : 1)
