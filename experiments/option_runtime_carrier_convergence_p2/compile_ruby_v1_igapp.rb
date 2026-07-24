#!/usr/bin/env ruby
# frozen_string_literal: true

# Compile one Igniter source unit through the canonical Ruby pipeline and
# assemble a first_class_v1 .igapp directory. This is a focused cross-toolchain
# evidence front door; runtime authority remains with igniter-vm.

require "json"
require "pathname"

ROOT = Pathname.new(__dir__).expand_path.parent.parent
$LOAD_PATH.unshift((ROOT / "lib").to_s)

require "igniter_lang"

source_path, target_path = ARGV
unless source_path && target_path
  warn "usage: ruby #{Pathname.new(__FILE__).relative_path_from(ROOT)} SOURCE.ig TARGET.igapp"
  exit 64
end

source = Pathname.new(source_path).expand_path
target = Pathname.new(target_path).expand_path
unless source.file?
  warn "source does not exist: #{source}"
  exit 66
end
if target.exist?
  warn "target already exists: #{target}"
  exit 73
end

parsed = IgniterLang::ParsedProgram.parse(
  File.read(source, encoding: "UTF-8"),
  source_path: source.to_s
).to_h
unless parsed.fetch("parse_errors", []).empty?
  warn JSON.pretty_generate("phase" => "parse", "errors" => parsed.fetch("parse_errors"))
  exit 2
end

classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
typed = IgniterLang::TypeChecker.new(optional_fields: true).typecheck(classified)
emitted = IgniterLang::SemanticIREmitter.new.emit_typed(typed)
report = emitted.fetch("compilation_report")
semantic_ir = emitted.fetch("semantic_ir")

unless report["pass_result"] == "ok" && semantic_ir
  warn JSON.pretty_generate(
    "phase" => "typecheck",
    "pass_result" => report["pass_result"],
    "diagnostics" => report.fetch("diagnostics", [])
  )
  exit 3
end

case_name = source.basename(".ig").to_s
summary = IgniterLang::Assembler.new.assemble_artifacts(
  case_name: case_name,
  report: report,
  semantic_ir: semantic_ir,
  target_dir: target
)

puts JSON.pretty_generate(
  summary.merge(
    "source" => source.to_s,
    "target" => target.to_s,
    "option_carrier" => semantic_ir.fetch("option_carrier"),
    "semantic_hash_law" => IgniterLang::Assembler::SEMANTIC_HASH_LAW
  )
)
