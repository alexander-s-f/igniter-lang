#!/usr/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

# LANG-EMPTY-COLLECTION-TYPE-PARITY-P1: Implementation Proof (Ruby canon side)
#
# Law: an empty collection literal `[]` receives type `Collection[T]` whenever the
# immediate expected type is exactly and unambiguously `Collection[T]`. The typed
# node must CARRY the contextual element type (not merely pass validation while
# staying Collection[Unknown]). A free-standing/ambiguous `[]` keeps
# Collection[Unknown]; no default element type is ever invented.
#
# Sections:
#   A — Positive matrix: annotated compute / required record field / nested
#       required record field / typed contract argument — clean AND evidence-carrying
#   B — Output-position seam (unannotated compute + Collection output) — Rust
#       LAB-TC-ARRAY-P1 twin
#   C — Negatives: Text member refused at all three sites; unconstrained `[]`
#       keeps Collection[Unknown]; a NON-literal Collection[Unknown] value is
#       never retyped
#   D — Diagnostic quality: record-field mismatch now displays parameterised types
#   E — Variant payload row: expected-type propagation + mismatch refusal
#       (implemented by LANG-VARIANT-PAYLOAD-EXPECTED-TYPE-PROPAGATION-P1)
#   F — Optional-field P3 semantics unchanged (gate ON: empty literal in a
#       declared-optional Collection field keeps the P3 Some-wrap behavior)

$LOAD_PATH.unshift(File.join(__dir__, "../../lib"))
require "igniter_lang"

PASS = "PASS"
FAIL = "FAIL"
@results = []

def check(label, condition, detail = nil)
  status = condition ? PASS : FAIL
  @results << [label, status]
  puts "#{status}  #{label}#{detail ? " — #{detail}" : ""}"
end

# Mirror the CompilerOrchestrator check pipeline (sugar lowering included).
def typecheck(src, optional_fields: false)
  parsed = IgniterLang::ParsedProgram.parse(src, source_path: "inline").to_h
  raise "parse errors: #{parsed["parse_errors"].inspect}" unless parsed.fetch("parse_errors").empty?
  IgniterLang::DerivedConstructorSugar.lower!(parsed)
  IgniterLang::ContractCallSugar.lower!(parsed)
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  IgniterLang::TypeChecker.new(optional_fields: optional_fields).typecheck(classified)
end

def errors(result)
  result.fetch("contracts", []).flat_map { |c| c.fetch("type_errors", []) } +
    result.fetch("type_errors", [])
end

def clean?(result)
  errors(result).empty?
end

def messages(result)
  errors(result).map { |e| "#{e["rule"]}: #{e["message"]}" }
end

def decl(result, contract_name, decl_name)
  c = result.fetch("contracts").find { |x| x["name"] == contract_name }
  c.fetch("declarations").find { |d| d["name"] == decl_name }
end

def type_str(t)
  return t.to_s unless t.is_a?(Hash)
  params = t.fetch("params", [])
  return t.fetch("name") if params.empty?
  "#{t.fetch("name")}[#{params.map { |p| type_str(p) }.join(",")}]"
end

COLLECTION_INTEGER = "Collection[Integer]"

puts "── A: positive matrix ──────────────────────────────────────────────────"

src_a = <<~IG
  module EmptyCtx

  type Inner {
    items: Collection[Integer]
  }

  type Holder {
    requests: Collection[Integer],
    inner: Inner
  }

  pure contract TakeList {
    input xs : Collection[Integer]
    compute n = count(xs)
    output n : Integer
  }

  pure contract Demo {
    compute direct : Collection[Integer] = []
    compute holder : Holder = {
      requests: [],
      inner: { items: [] }
    }
    compute via_contract = TakeList([])
    compute result = count(direct) + count(holder.requests) + via_contract
    output result : Integer
  }
IG

ra = typecheck(src_a)
check("A-01 full matrix source is clean", clean?(ra), messages(ra).inspect)

direct = decl(ra, "Demo", "direct")
check("A-02 annotated compute: binding type is #{COLLECTION_INTEGER}",
      type_str(direct["type"]) == COLLECTION_INTEGER, type_str(direct["type"]))
check("A-03 annotated compute: EXPR node carries #{COLLECTION_INTEGER} (not Collection[Unknown])",
      type_str(direct.dig("expr", "resolved_type")) == COLLECTION_INTEGER,
      type_str(direct.dig("expr", "resolved_type")))
check("A-04 annotated compute: literal node stays EMPTY (evidence, not representation)",
      direct.dig("expr", "kind") == "array_literal" && direct.dig("expr", "items") == [])

holder = decl(ra, "Demo", "holder")
check("A-05 record compute resolves to Holder", type_str(holder["type"]) == "Holder")
req = holder.dig("expr", "fields", "requests")
check("A-06 required record field: typed field carries #{COLLECTION_INTEGER}",
      type_str(req && req["resolved_type"]) == COLLECTION_INTEGER, type_str(req && req["resolved_type"]))
check("A-07 required record field: literal stays EMPTY",
      req && req["kind"] == "array_literal" && req["items"] == [])
nested = holder.dig("expr", "fields", "inner", "fields", "items")
check("A-08 nested required record field: typed field carries #{COLLECTION_INTEGER}",
      type_str(nested && nested["resolved_type"]) == COLLECTION_INTEGER, type_str(nested && nested["resolved_type"]))
check("A-09 nested required record field: literal stays EMPTY",
      nested && nested["kind"] == "array_literal" && nested["items"] == [])

via = decl(ra, "Demo", "via_contract")
arg = via.dig("expr", "args", 1)
check("A-10 typed contract argument: typed arg carries #{COLLECTION_INTEGER}",
      type_str(arg && arg["resolved_type"]) == COLLECTION_INTEGER, type_str(arg && arg["resolved_type"]))
check("A-11 typed contract argument: literal stays EMPTY",
      arg && arg["kind"] == "array_literal" && arg["items"] == [])
check("A-12 contract call output resolves (Integer)",
      type_str(via["type"]) == "Integer", type_str(via["type"]))

puts
puts "── B: output-position seam (Rust LAB-TC-ARRAY-P1 twin) ────────────────"

src_b = <<~IG
  module OutHint
  pure contract Demo {
    compute xs = []
    output xs : Collection[Integer]
  }
IG
rb = typecheck(src_b)
check("B-01 unannotated compute + Collection output is clean", clean?(rb), messages(rb).inspect)
xs = decl(rb, "Demo", "xs")
check("B-02 binding adopts #{COLLECTION_INTEGER} from the output declaration",
      type_str(xs["type"]) == COLLECTION_INTEGER, type_str(xs["type"]))
check("B-03 expr node carries #{COLLECTION_INTEGER}",
      type_str(xs.dig("expr", "resolved_type")) == COLLECTION_INTEGER)

puts
puts "── C: negatives (refusals + no evidence erasure) ──────────────────────"

neg_field = typecheck(<<~IG)
  module NegField
  type Holder {
    requests: Collection[Integer]
  }
  pure contract Demo {
    compute holder : Holder = { requests: ["oops"] }
    compute result = count(holder.requests)
    output result : Integer
  }
IG
check("C-01 record field with Text member refuses (OOF-TY0)",
      errors(neg_field).any? { |e| e["rule"] == "OOF-TY0" && e["message"].include?("requests") },
      messages(neg_field).inspect)

neg_compute = typecheck(<<~IG)
  module NegCompute
  pure contract Demo {
    compute xs : Collection[Integer] = ["oops"]
    compute result = count(xs)
    output result : Integer
  }
IG
check("C-02 annotated compute with Text member refuses (OOF-TY0 binding mismatch)",
      errors(neg_compute).any? { |e| e["rule"] == "OOF-TY0" && e["message"].include?("Binding type mismatch") },
      messages(neg_compute).inspect)

neg_arg = typecheck(<<~IG)
  module NegArg
  pure contract TakeList {
    input xs : Collection[Integer]
    compute n = count(xs)
    output n : Integer
  }
  pure contract Demo {
    compute result = TakeList(["oops"])
    output result : Integer
  }
IG
check("C-03 contract argument with Text member refuses (OOF-TY0 names the parameter)",
      errors(neg_arg).any? { |e| e["rule"] == "OOF-TY0" && e["message"].include?("parameter 'xs'") },
      messages(neg_arg).inspect)

unconstrained = typecheck(<<~IG)
  module Unconstrained
  pure contract Demo {
    compute xs = []
    compute result = count(xs)
    output result : Integer
  }
IG
check("C-04 unconstrained `compute xs = []` stays clean (current behavior preserved)",
      clean?(unconstrained), messages(unconstrained).inspect)
uxs = decl(unconstrained, "Demo", "xs")
check("C-05 unconstrained `[]` keeps Collection[Unknown] (no invented element type)",
      type_str(uxs["type"]) == "Collection[Unknown]", type_str(uxs["type"]))

# A NON-literal Collection[Unknown] value must never be retyped by the seam —
# only the empty array_literal node itself is contextualized.
ref_pass = typecheck(<<~IG)
  module RefPass
  pure contract TakeList {
    input xs : Collection[Integer]
    compute n = count(xs)
    output n : Integer
  }
  pure contract Demo {
    compute ys = []
    compute result = TakeList(ys)
    output result : Integer
  }
IG
ref_arg = decl(ref_pass, "Demo", "result").dig("expr", "args", 1)
check("C-06 a REF argument (non-literal) is not retyped by the seam",
      ref_arg && ref_arg["kind"] == "ref" && type_str(ref_arg["resolved_type"]) == "Collection[Unknown]",
      ref_arg && "#{ref_arg["kind"]}: #{type_str(ref_arg["resolved_type"])}")

puts
puts "── D: diagnostic quality ───────────────────────────────────────────────"

check("D-01 record-field mismatch displays FULL parameterised types",
      errors(neg_field).any? { |e| e["message"].include?("expected Collection[Integer], got Collection[String]") },
      messages(neg_field).inspect)
check("D-02 the misleading same-name rendering is gone for this case",
      errors(neg_field).none? { |e| e["message"].include?("expected Collection, got Collection") },
      messages(neg_field).inspect)

puts
puts "── E: variant payload expected-type propagation ───────────────────────"

variant = typecheck(<<~IG)
  module VariantProbe

  variant Payload {
    Batch { ids: Collection[Integer] }
    Nothing { }
  }

  pure contract Demo {
    compute p : Payload = Batch { ids: [] }
    compute result = 1
    output result : Integer
  }
IG
check("E-01 variant payload `ids: []` is accepted",
      clean?(variant), messages(variant).inspect)
vids = decl(variant, "Demo", "p").dig("expr", "typed_fields", "ids")
check("E-02 payload evidence carries Collection[Integer] under the arm-field expected type",
      vids && type_str(vids["resolved_type"]) == COLLECTION_INTEGER,
      vids && type_str(vids["resolved_type"]))

variant_mismatch = typecheck(<<~IG)
  module VariantMismatch

  variant Payload {
    Batch { ids: Collection[Integer] }
  }

  pure contract Demo {
    compute p : Payload = Batch { ids: ["wrong"] }
    compute result = 1
    output result : Integer
  }
IG
check("E-03 concrete variant payload mismatch refuses with full parameterised types",
      errors(variant_mismatch).any? do |e|
        e["rule"] == "OOF-KIND2" &&
          e["message"].include?("expected Collection[Integer], got Collection[String]")
      end, messages(variant_mismatch).inspect)

puts
puts "── F: optional-field P3 semantics unchanged (gate ON) ─────────────────"

optional = typecheck(<<~IG, optional_fields: true)
  module OptionalProbe
  type Prefs {
    name: Text,
    tags: Collection[Integer]?
  }
  pure contract Demo {
    compute p : Prefs = { name: "a", tags: [] }
    compute result = 1
    output result : Integer
  }
IG
check("F-01 optional Collection field with `[]` stays clean (P3 unchanged)",
      clean?(optional), messages(optional).inspect)
otags = decl(optional, "Demo", "p").dig("expr", "fields", "tags")
check("F-02 optional field keeps Some-wrap semantics under the P2 nominal carrier",
      otags && otags["kind"] == "option_value_construct" && otags["arm"] == "Some",
      otags && otags["kind"])

puts
failed = @results.count { |_, s| s == FAIL }
puts
puts "Result: #{@results.size - failed}/#{@results.size} PASS"
if failed.zero?
  puts "VERDICT: PASS — LANG-EMPTY-COLLECTION-TYPE-PARITY-P1 (Ruby canon side) holds"
else
  puts "VERDICT: FAIL — #{failed} check(s) failed"
  exit 1
end
