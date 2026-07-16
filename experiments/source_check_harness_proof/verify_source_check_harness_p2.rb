#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "pathname"
require "rbconfig"
require "tmpdir"

ROOT = Pathname.new(__dir__).parent.parent
$LOAD_PATH.unshift(ROOT.join("lib").to_s)
require "igniter_lang/compiler_orchestrator"

LAB_ROOT = Pathname.new(ENV.fetch("IGNITER_LAB_ROOT"))
PROTEIN = LAB_ROOT.join("apps/igniter-apps/protein_fold")
SOURCES = %w[types predict evidence provenance example].map { |name| PROTEIN.join("#{name}.ig") }
CHECKS = []

def check(label)
  passed = yield
  CHECKS << [label, passed]
  puts "#{passed ? 'PASS' : 'FAIL'}  #{label}"
rescue => e
  CHECKS << [label, false]
  puts "ERROR #{label}: #{e.class}: #{e.message}"
end

def snapshot(root)
  root.glob("**/*", File::FNM_DOTMATCH)
      .select(&:file?)
      .sort_by(&:to_s)
      .to_h { |path| [path.relative_path_from(root).to_s, Digest::SHA256.file(path).hexdigest] }
end

def cli(*args)
  Open3.capture3(
    RbConfig.ruby,
    "-I#{ROOT.join('lib')}",
    ROOT.join("bin/igc").to_s,
    *args.map(&:to_s)
  )
end

class ForbiddenEmitter
  attr_reader :called

  def initialize
    @called = false
  end

  def emit_typed(*)
    @called = true
    raise "emitter invoked by source check"
  end
end

class ForbiddenAssembler
  attr_reader :called

  def initialize
    @called = false
  end

  def assemble_artifacts(*)
    @called = true
    raise "assembler invoked by source check"
  end
end

raise "protein_fold sources unavailable under IGNITER_LAB_ROOT=#{LAB_ROOT}" unless SOURCES.all?(&:file?)

before = snapshot(PROTEIN)
emitter = ForbiddenEmitter.new
assembler = ForbiddenAssembler.new
orchestrator = IgniterLang::CompilerOrchestrator.new(emitter: emitter, assembler: assembler)
receipt = orchestrator.check_sources(source_paths: SOURCES)

check("native five-source check is clean") { receipt.fetch("status") == "clean" && receipt.fetch("exit_code") == 0 }
check("native check resolves five units and sixteen contracts") do
  receipt.dig("source_set", "resolved_units").length == 5 && receipt.fetch("contract_ids").length == 16
end
check("resolved units preserve deterministic module/path/hash evidence") do
  units = receipt.dig("source_set", "resolved_units")
  units.map { |unit| unit.fetch("module") } == units.map { |unit| unit.fetch("module") }.sort &&
    units.all? { |unit| unit.fetch("path").start_with?(LAB_ROOT.to_s) && unit.fetch("sha256").start_with?("sha256:") }
end
check("emitter and assembler spies stay uncalled") { !emitter.called && !assembler.called }
check("native clean check leaves protein_fold byte-identical") { snapshot(PROTEIN) == before }
check("native stages stop before emission") do
  receipt.dig("stages", "emit") == "not_run" && receipt.dig("stages", "assemble") == "not_run"
end

Dir.mktmpdir("canon_source_check") do |dir|
  root = Pathname.new(dir)
  invalid = root.join("invalid.ig")
  invalid.write(<<~IG)
    module InvalidAssumption

    assumptions {
      assumption bad {
        kind: :observed
        statement: "bad"
        strength: 3
      }
    }

    pure contract Main {
      compute n : Integer = 1
      output n : Integer
    }
  IG
  invalid_utf8 = root.join("invalid_utf8.ig")
  invalid_utf8.binwrite("\xFF\xFE")
  temp_before = snapshot(root)

  bad = orchestrator.check_sources(source_paths: [invalid])
  check("invalid strength is refused with exactly one TASSUMP-1") do
    bad.fetch("exit_code") == 1 &&
      bad.fetch("diagnostics").count { |diag| diag.fetch("rule") == "TASSUMP-1" } == 1
  end
  check("refused native check leaves filesystem byte-identical") { snapshot(root) == temp_before }

  stdout1, stderr1, status1 = cli("check", *SOURCES, "--json")
  stdout2, stderr2, status2 = cli("check", *SOURCES, "--json")
  check("public JSON CLI is deterministic and clean") do
    status1.exitstatus == 0 && status2.exitstatus == 0 && stderr1.empty? && stderr2.empty? && stdout1 == stdout2
  end
  check("public JSON CLI returns the native canon receipt") do
    parsed = JSON.parse(stdout1)
    parsed.fetch("toolchain") == "ruby_canon" && parsed.fetch("status") == "clean"
  end

  usage_out, usage_err, usage_status = cli("check", "--json")
  check("usage path is exit 2 and one JSON document") do
    usage_status.exitstatus == 2 && usage_err.empty? && JSON.parse(usage_out).fetch("status") == "usage_error"
  end
  internal_out, internal_err, internal_status = cli("check", invalid_utf8, "--json")
  check("internal path is exit 3 and one JSON document") do
    internal_status.exitstatus == 3 && internal_err.empty? && JSON.parse(internal_out).fetch("status") == "internal_error"
  end
  check("usage/internal CLI paths leave filesystem byte-identical") { snapshot(root) == temp_before }

  human1, human_err1, human_status1 = cli("check", *SOURCES)
  human2, human_err2, human_status2 = cli("check", *SOURCES)
  check("public human CLI is deterministic and clean") do
    human_status1.exitstatus == 0 && human_status2.exitstatus == 0 &&
      human_err1.empty? && human_err2.empty? && human1 == human2 && human1.start_with?("Canon source check: clean")
  end
end

failed = CHECKS.reject { |(_, passed)| passed }
puts "#{CHECKS.length - failed.length}/#{CHECKS.length} checks passed"
exit(failed.empty? ? 0 : 1)
