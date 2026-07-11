#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "tmpdir"
require_relative "../../lib/igniter_lang/compiler_orchestrator"
require_relative "../../lib/igniter_lang/const_resolver"

checks = []
check = ->(name, ok) { raise "FAIL: #{name}" unless ok; checks << name }

source = <<~IG
  module Proof.Const
  type Track { instrument : String gain : Integer }
  const gain : Integer = 100
  const enabled : Bool = true
  const ratio : Decimal[2] = 1.25
  const kick : Track = { instrument: "kick", gain: gain }
  const song : Collection[Track] = [kick]
  pure contract Use { compute tracks : Collection[Track] = song output tracks : Collection[Track] }
IG
parsed = IgniterLang::ParsedProgram.parse(source).to_h
check.call("positive_parse", parsed.fetch("parse_errors").empty?)
check.call("positive_resolve", IgniterLang::ConstResolver.resolve_single!(parsed).empty?)
compute = parsed.fetch("contracts").first.fetch("body").find { |decl| decl.fetch("kind") == "compute" }
check.call("inline_array", compute.dig("expr", "kind") == "array_literal")
check.call("no_runtime_const_node", !JSON.generate(compute.fetch("expr")).include?('"kind":"const"'))
golden = JSON.parse(File.read(File.join(__dir__, "golden", "module_const_inlining.json")))
check.call("golden_inline", compute.fetch("expr") == golden.fetch("resolved_expr"))

{
  "duplicate" => ["module T const a : Integer = 1 const a : Integer = 2", "OOF-DECL-DUP-CONST"],
  "unknown" => ["module T const a : Integer = missing", "OOF-CONST-UNKNOWN"],
  "cycle" => ["module T const a : Integer = b const b : Integer = a", "OOF-CONST-CYCLE"],
  "call" => ["module T const a : Integer = f()", "OOF-CONST-LITERAL"],
  "if" => ["module T const a : Integer = if true { 1 } else { 2 }", "OOF-CONST-LITERAL"]
}.each do |name, (src, rule)|
  candidate = IgniterLang::ParsedProgram.parse(src).to_h
  candidate.fetch("parse_errors").concat(IgniterLang::ConstResolver.resolve_single!(candidate)) if candidate.fetch("parse_errors").empty?
  check.call(name, candidate.fetch("parse_errors").any? { |diag| diag.fetch("rule", nil) == rule })
end

Dir.mktmpdir("module_const") do |dir|
  types = File.join(dir, "types.ig")
  use = File.join(dir, "use.ig")
  File.write(types, "module A\nconst answer : Integer = 42\n")
  File.write(use, "module B\nimport A.{ answer }\npure contract C { compute x = answer output x : Integer }\n")
  result = IgniterLang::CompilerOrchestrator.new.compile_sources(
    source_paths: [types, use], out_path: File.join(dir, "out.igapp")
  )
  check.call("imported_const_compile", result.fetch("status") == "ok")
  check.call("imported_const_inlined", JSON.generate(result.fetch("semantic_ir")).include?("42"))
end

Dir.mktmpdir("module_const_bad_shape") do |dir|
  path = File.join(dir, "bad.ig")
  File.write(path, "module T type R { n : Integer } const bad : R = { n: \"x\" }")
  result = IgniterLang::CompilerOrchestrator.new.compile(source_path: path, out_path: File.join(dir, "out.igapp"))
  check.call("wrong_shape", result.dig("compilation_report", "diagnostics").any? { |diag| diag.fetch("rule") == "OOF-TY0" })
end

puts JSON.pretty_generate("status" => "PASS", "checks" => checks.length, "cases" => checks)
