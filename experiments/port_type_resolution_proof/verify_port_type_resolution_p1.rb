#!/usr/bin/env ruby
# frozen_string_literal: true

# LANG-TYPE-REF-UNRESOLVED-FAIL-CLOSED-P1 — canon proof.
# Contract ports resolve through builtins and the complete multifile record/variant registry;
# undeclared nominal leaves fail before assembly and never leave an artifact.

require "fileutils"
require "tmpdir"

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
require "igniter_lang"
require "igniter_lang/compiler_orchestrator"

$pass = 0
$fail = 0

def check(label)
  ok = yield
  if ok
    $pass += 1
    puts "PASS  #{label}"
  else
    $fail += 1
    puts "FAIL  #{label}"
  end
rescue StandardError => e
  $fail += 1
  puts "FAIL  #{label} [#{e.class}: #{e.message.lines.first&.strip}]"
end

def typecheck(source)
  parsed = IgniterLang::ParsedProgram.parse(source, source_path: "inline").to_h
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  IgniterLang::TypeChecker.new.typecheck(classified)
end

def diagnostics(result)
  result.fetch("type_errors", [])
end

def unresolved(result)
  diagnostics(result).select do |diagnostic|
    diagnostic["rule"] == "OOF-TY0" && diagnostic["message"].include?("Unresolved type reference")
  end
end

def clean?(source)
  diagnostics(typecheck(source)).empty?
end

def exact_unresolved?(source, message)
  matches = unresolved(typecheck(source))
  matches.length == 1 && matches.first["message"] == message
end

positive = <<~IG
  module Port.Positive
  type Payload { value : Integer }
  variant Outcome { Good { value : Integer } Bad { reason : Text } }
  pure contract Keep {
    input payload : Payload
    input outcome : Outcome
    input nested : Result[Collection[Integer], Text]
    input history : History
    output payload : Payload
  }
IG

recursive = <<~IG
  module Port.Recursive
  type Node { value : Integer next : Option[Node] }
  type Left { right : Option[Right] }
  type Right { left : Option[Left] }
  pure contract Keep { input node : Node input left : Left output node : Node }
IG

check("builtin, record, variant and nested constructor ports resolve") { clean?(positive) }
check("recursive and mutually recursive declared shapes terminate") { clean?(recursive) }

check("direct unresolved input is one exact OOF-TY0") do
  exact_unresolved?(
    "module Port.BadInput\npure contract BrokenPort { input value : Foo.Bar }\n",
    "Unresolved type reference 'Foo.Bar' in input 'value' of contract 'BrokenPort'"
  )
end

check("direct unresolved output is one exact OOF-TY0") do
  exact_unresolved?(
    "module Port.BadOutput\npure contract BrokenPort { compute value = 1 output value : Foo.Bar }\n",
    "Unresolved type reference 'Foo.Bar' in output 'value' of contract 'BrokenPort'"
  )
end

check("nested unresolved leaf is rejected") do
  exact_unresolved?(
    "module Port.BadNested\npure contract BrokenPort { input value : Collection[Foo.Bar] }\n",
    "Unresolved type reference 'Foo.Bar' in input 'value' of contract 'BrokenPort'"
  )
end

check("declared outer record cannot hide an unresolved reachable field") do
  exact_unresolved?(
    "module Port.BadReachable\ntype Wrapper { value : Foo.Bar }\npure contract BrokenPort { input wrapped : Wrapper }\n",
    "Unresolved type reference 'Foo.Bar' in input 'wrapped' of contract 'BrokenPort'"
  )
end

check("variant-arm-like spelling stays unresolved") do
  exact_unresolved?(
    "module Port.BadArm\nvariant Evidence { Observed { value : Integer } }\npure contract BrokenPort { input value : Evidence.Observed }\n",
    "Unresolved type reference 'Evidence.Observed' in input 'value' of contract 'BrokenPort'"
  )
end

check("malformed builtin constructor arity fails closed") do
  result = typecheck("module Port.BadArity\npure contract BrokenPort { input value : Collection[Integer, Text] }\n")
  diagnostics(result).any? do |diagnostic|
    diagnostic["rule"] == "OOF-TY0" &&
      diagnostic["message"] == "Type constructor 'Collection' expects 1 parameter(s), got 2 in input 'value' of contract 'BrokenPort'"
  end
end

check("direct Unknown port is refused") do
  exact_unresolved?(
    "module Port.BadUnknown\npure contract BrokenPort { input value : Unknown }\n",
    "Unresolved type reference 'Unknown' in input 'value' of contract 'BrokenPort'"
  )
end

check("nested Unknown JSON idiom remains accepted") do
  clean?("module Port.NestedUnknown\npure contract Keep { input value : Map[String, Unknown] }\n")
end

Dir.mktmpdir("port-type-resolution-proof") do |dir|
  types = File.join(dir, "types.ig")
  user = File.join(dir, "user.ig")
  artifact = File.join(dir, "imported.igapp")
  File.write(types, "module Port.Types\ntype Payload { value : Integer }\nvariant Outcome { Good { value : Integer } }\n")
  File.write(user, "module Port.User\nimport Port.Types.{ Payload, Outcome }\npure contract Keep { input payload : Payload input outcome : Outcome output payload : Payload }\n")
  result = IgniterLang::CompilerOrchestrator.new.compile_sources(
    source_paths: [types, user],
    out_path: artifact
  )
  check("multifile imported record and variant ports resolve") do
    result.fetch("status") == "ok" && File.directory?(artifact)
  end
end

Dir.mktmpdir("port-type-resolution-refusal") do |dir|
  source = File.join(dir, "broken.ig")
  artifact = File.join(dir, "broken.igapp")
  File.write(source, "module Port.Refusal\npure contract BrokenPort { input value : Foo.Bar }\n")
  result = IgniterLang::CompilerOrchestrator.new.compile(
    source_path: source,
    out_path: artifact
  )
  report = result.fetch("compilation_report", {})
  report_diagnostics = report.fetch("diagnostics", [])
  check("normal compile refuses before assembly") do
    result.fetch("status") != "ok" && report_diagnostics.any? { |d| d["rule"] == "OOF-TY0" }
  end
  check("refused canon source leaves no artifact") { !File.exist?(artifact) }
end

mismatch = typecheck("module Port.Mismatch\npure contract C { compute value = 1 output value : Text }\n")
check("ordinary output mismatch keeps OOF-TY1 without unresolved-reference wording") do
  diagnostics(mismatch).any? { |d| d["rule"] == "OOF-TY1" && d["message"].include?("Output type mismatch") } &&
    unresolved(mismatch).empty?
end

puts "#{$pass}/#{$pass + $fail} checks passed"
exit($fail.zero? ? 0 : 1)
