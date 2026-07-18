#!/usr/bin/env ruby
# frozen_string_literal: true

# LANG-VARIANT-PAYLOAD-EXPECTED-TYPE-PROPAGATION-P1
#
# Law: each supplied variant-constructor field is inferred and validated under
# the arm field's declared type. Empty collection literals carry Collection[T]
# evidence, concrete mismatches refuse, declared Unknown stays open, and no
# expected type leaks into a free-standing literal.

require "json"
require "tmpdir"

$LOAD_PATH.unshift(File.join(__dir__, "../../lib"))
require "igniter_lang"
require "igniter_lang/compiler_orchestrator"

PASS = "PASS"
FAIL = "FAIL"
@results = []

def check(label, condition, detail = nil)
  status = condition ? PASS : FAIL
  @results << [label, status]
  puts "#{status}  #{label}#{detail ? " — #{detail}" : ""}"
end

def typecheck(src)
  parsed = IgniterLang::ParsedProgram.parse(src, source_path: "inline").to_h
  raise "parse errors: #{parsed.fetch("parse_errors").inspect}" unless parsed.fetch("parse_errors").empty?
  IgniterLang::DerivedConstructorSugar.lower!(parsed)
  IgniterLang::ContractCallSugar.lower!(parsed)
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  IgniterLang::TypeChecker.new.typecheck(classified)
end

def compile_sir(src)
  Dir.mktmpdir("variant-payload-expected-type-ruby") do |dir|
    source = File.join(dir, "case.ig")
    artifact = File.join(dir, "case.igapp")
    File.write(source, src)
    result = IgniterLang::CompilerOrchestrator.new.compile(source_path: source, out_path: artifact)
    sir_path = File.join(artifact, "semantic_ir_program.json")
    [result, File.exist?(sir_path) ? JSON.parse(File.read(sir_path)) : nil]
  end
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

def decl(result, contract, name)
  typed_contract = result.fetch("contracts").find { |c| c["name"] == contract }
  typed_contract.fetch("declarations").find { |d| d["name"] == name }
end

def sir_node(sir, contract, name)
  sir.fetch("contracts").find { |c| c["contract_name"] == contract }
     .fetch("nodes").find { |n| n["name"] == name }
end

def type_str(type)
  return type.to_s unless type.is_a?(Hash)
  params = type.fetch("params", [])
  return type.fetch("name") if params.empty?
  "#{type.fetch("name")}[#{params.map { |p| type_str(p) }.join(",")}]"
end

collection_integer = "Collection[Integer]"

puts "── A: empty collection payload carries expected type ─────────────────"

empty_src = <<~IG
  module VariantPayloadEmpty
  variant Payload { Batch { ids: Collection[Integer] } }
  pure contract Build {
    compute payload : Payload = Batch { ids: [] }
    output payload : Payload
  }
IG
empty = typecheck(empty_src)
empty_ids = decl(empty, "Build", "payload").dig("expr", "typed_fields", "ids")
check("A-01 empty payload is clean", clean?(empty), messages(empty).inspect)
check("A-02 typed field carries #{collection_integer}",
      type_str(empty_ids && empty_ids["resolved_type"]) == collection_integer,
      type_str(empty_ids && empty_ids["resolved_type"]))
check("A-03 empty literal representation stays empty",
      empty_ids && empty_ids["kind"] == "array_literal" && empty_ids["items"] == [])
compile_result, empty_sir = compile_sir(empty_src)
sir_ids = empty_sir && sir_node(empty_sir, "Build", "payload").dig("expr", "fields", "ids")
check("A-04 emitted Ruby SIR field carries #{collection_integer}",
      compile_result["status"] == "ok" && type_str(sir_ids && sir_ids["resolved_type"]) == collection_integer,
      sir_ids && type_str(sir_ids["resolved_type"]))

puts
puts "── B: concrete matching collection stays clean ───────────────────────"

filled_src = empty_src.sub("ids: []", "ids: [1, 2]")
filled = typecheck(filled_src)
filled_ids = decl(filled, "Build", "payload").dig("expr", "typed_fields", "ids")
check("B-01 Collection[Integer] payload is clean", clean?(filled), messages(filled).inspect)
check("B-02 matching payload field carries #{collection_integer}",
      type_str(filled_ids && filled_ids["resolved_type"]) == collection_integer,
      type_str(filled_ids && filled_ids["resolved_type"]))

puts
puts "── C: concrete mismatch refuses ───────────────────────────────────────"

mismatch = typecheck(empty_src.sub("ids: []", 'ids: ["wrong"]'))
check("C-01 Collection[String] payload refuses with OOF-KIND2",
      errors(mismatch).any? { |e| e["rule"] == "OOF-KIND2" }, messages(mismatch).inspect)
check("C-02 diagnostic renders full expected and actual types",
      errors(mismatch).any? do |e|
        e["message"].include?("expected Collection[Integer], got Collection[String]")
      end, messages(mismatch).inspect)

puts
puts "── D: nested required record remains structural ──────────────────────"

nested_src = <<~IG
  module VariantPayloadNested
  type Holder { ids: Collection[Integer] }
  variant Payload { Wrapped { holder: Holder } }
  pure contract Build {
    compute payload : Payload = Wrapped { holder: { ids: [] } }
    output payload : Payload
  }
IG
nested = typecheck(nested_src)
holder = decl(nested, "Build", "payload").dig("expr", "typed_fields", "holder")
check("D-01 nested record payload is clean", clean?(nested), messages(nested).inspect)
check("D-02 variant field carries Holder", type_str(holder && holder["resolved_type"]) == "Holder")
check("D-03 Holder.ids carries #{collection_integer}",
      type_str(holder&.dig("fields", "ids", "resolved_type")) == collection_integer,
      type_str(holder&.dig("fields", "ids", "resolved_type")))
nested_bad = typecheck(nested_src.sub("ids: []", 'ids: ["wrong"]'))
check("D-04 nested concrete mismatch remains fail-closed",
      errors(nested_bad).any? { |e| e["rule"] == "OOF-TY0" && e["message"].include?("ids") },
      messages(nested_bad).inspect)

puts
puts "── E: declared Unknown stays open ─────────────────────────────────────"

open_src = <<~IG
  module VariantPayloadOpen
  variant Payload { Open { value: Unknown } }
  pure contract Build {
    compute payload : Payload = Open { value: "text" }
    output payload : Payload
  }
IG
open_result = typecheck(open_src)
open_value = decl(open_result, "Build", "payload").dig("expr", "typed_fields", "value")
check("E-01 concrete value into declared Unknown stays clean",
      clean?(open_result), messages(open_result).inspect)
check("E-02 concrete evidence is retained in the open field",
      type_str(open_value && open_value["resolved_type"]) == "String")

puts
puts "── F: boundary controls ────────────────────────────────────────────────"

free = typecheck(<<~IG)
  module VariantPayloadFree
  pure contract Build {
    compute xs = []
    compute result = count(xs)
    output result : Integer
  }
IG
free_xs = decl(free, "Build", "xs")
check("F-01 free-standing [] keeps current clean behavior", clean?(free), messages(free).inspect)
check("F-02 free-standing [] remains Collection[Unknown]",
      type_str(free_xs["type"]) == "Collection[Unknown]", type_str(free_xs["type"]))

missing = typecheck(empty_src.sub("Batch { ids: [] }", "Batch { }"))
check("F-03 missing payload field keeps OOF-KIND2",
      errors(missing).any? { |e| e["rule"] == "OOF-KIND2" && e["message"].include?("missing required field 'ids'") },
      messages(missing).inspect)

unexpected = typecheck(empty_src.sub("ids: []", "ids: [], extra: 1"))
check("F-04 unexpected payload field keeps OOF-KIND2",
      errors(unexpected).any? { |e| e["rule"] == "OOF-KIND2" && e["message"].include?("extra") },
      messages(unexpected).inspect)

duplicate_source = empty_src.sub("ids: []", "ids: [], ids: [1]")
duplicate_parse = IgniterLang::ParsedProgram.parse(duplicate_source, source_path: "inline").to_h
check("F-05 duplicate payload field keeps parser OOF-P1",
      duplicate_parse.fetch("parse_errors").any? do |e|
        e["rule"] == "OOF-P1" && e["message"].include?("duplicate field `ids`")
      end, duplicate_parse.fetch("parse_errors").inspect)

failed = @results.count { |_, status| status == FAIL }
puts
puts "Result: #{@results.length - failed}/#{@results.length} PASS"
if failed.zero?
  puts "VERDICT: PASS — variant payload expected-type propagation holds"
else
  puts "VERDICT: FAIL — #{failed} check(s) failed"
  exit 1
end
