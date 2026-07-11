#!/usr/bin/env ruby
# frozen_string_literal: true

# LANG-STDLIB-IMPORT-VALIDATION-FLAT-PARITY-P1 (FRUT-P07 / IGDB-P08 residual) —
# canon-toolchain proof.
#
# Flat single-file compiles used to accept bogus stdlib imports silently while
# the multifile path failed closed. This proof locks flat-mode honesty:
#   import stdlib.bogus.{ frobnicate }     → OOF-IMP2 (unknown namespace)
#   import stdlib.integer.{ frobnicate }   → OOF-IMP3 (unknown item, known ns)
#   import stdlib.numeric.{ modulo }       → OOF-IMP2 (alias = callable, not importable)
#   canonical imports (integer/collection/text) → ok
# plus the multifile path is unchanged (shared per-import helper still fires),
# and the igdb core-4 / igmesh pure flat sets still compile ok (read-only).

require "fileutils"
require "pathname"

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
require "igniter_lang/compiler_orchestrator"

module StdlibImportFlatValidationP1Proof
  module_function

  EXPERIMENT_DIR = Pathname.new(__dir__)
  FIXTURE_DIR = EXPERIMENT_DIR / "fixtures"
  OUT_DIR = EXPERIMENT_DIR / "out"
  LAB_APPS = EXPERIMENT_DIR / "../../../igniter-lab/apps/igniter-apps"
  CHECKS = []

  BOGUS_NS = <<~IG
    module Flat.BogusNs
    import stdlib.bogus.{ frobnicate }

    pure contract Echo {
      input value : Integer
      compute doubled = value + value
      output doubled : Integer
    }
  IG

  BOGUS_NAME = <<~IG
    module Flat.BogusName
    import stdlib.integer.{ frobnicate }

    pure contract A {
      input v : Integer
      compute n = v + 1
      output n : Integer
    }
  IG

  ALIAS_NS = <<~IG
    module Flat.Alias
    import stdlib.numeric.{ modulo }

    pure contract A {
      input v : Integer
      compute n = modulo(v, 2)
      output n : Integer
    }
  IG

  GOOD = <<~IG
    module Flat.Good
    import stdlib.integer.{ parse_int, int_to_text, modulo }
    import stdlib.collection.{ fold }
    import stdlib.text.{ join, encode_delimited, decode_delimited }

    pure contract Render {
      input value : Integer
      compute text = int_to_text(value)
      output text : String
    }
  IG

  PLAIN = <<~IG
    module Multi.A

    pure contract A {
      input v : Integer
      compute n = v + 1
      output n : Integer
    }
  IG

  def compile_flat(name, source)
    path = FIXTURE_DIR / "#{name}.ig"
    FileUtils.mkdir_p(FIXTURE_DIR)
    File.write(path, source)
    IgniterLang::CompilerOrchestrator.new.compile(
      source_path: path.to_s,
      out_path: (OUT_DIR / "#{name}.igapp").to_s
    )
  end

  def compile_multi(name, sources)
    dir = FIXTURE_DIR / name
    FileUtils.mkdir_p(dir)
    paths = sources.each_with_index.map do |source, index|
      path = dir / "u#{index}.ig"
      File.write(path, source)
      path.to_s
    end
    IgniterLang::CompilerOrchestrator.new.compile_sources(
      source_paths: paths,
      out_path: (OUT_DIR / "#{name}.igapp").to_s
    )
  end

  def status(result)
    (result[:status] || result["status"]).to_s
  end

  def diags(result)
    report = result["compilation_report"] || {}
    report["diagnostics"] || []
  end

  def rules(result)
    diags(result).map { |d| d["rule"] || d[:rule] }
  end

  def check(label, ok)
    CHECKS << [label, ok]
    puts "#{ok ? 'PASS' : 'FAIL'}  #{label}"
  end

  def run
    FileUtils.rm_rf(FIXTURE_DIR)
    FileUtils.rm_rf(OUT_DIR)
    FileUtils.mkdir_p(OUT_DIR)

    bogus_ns = compile_flat("bogus_ns", BOGUS_NS)
    check("flat unknown stdlib namespace -> oof OOF-IMP2",
          status(bogus_ns) == "oof" && rules(bogus_ns).include?("OOF-IMP2"))

    bogus_name = compile_flat("bogus_name", BOGUS_NAME)
    check("flat unknown name in known namespace -> oof OOF-IMP3",
          status(bogus_name) == "oof" && rules(bogus_name).include?("OOF-IMP3"))

    alias_ns = compile_flat("alias_ns", ALIAS_NS)
    check("flat alias namespace (stdlib.numeric) not importable -> oof OOF-IMP2",
          status(alias_ns) == "oof" && rules(alias_ns).include?("OOF-IMP2"))

    good = compile_flat("good", GOOD)
    check("flat canonical integer/collection/text imports -> ok",
          status(good) == "ok")

    multi = compile_multi("multi_bogus", [PLAIN, BOGUS_NS])
    check("multifile path unchanged: bogus namespace still oof OOF-IMP2",
          status(multi) == "oof" && rules(multi).include?("OOF-IMP2"))

    if LAB_APPS.directory?
      igdb = %w[types codec heap example].map { |f| (LAB_APPS / "igdb/#{f}.ig").to_s }
      r = IgniterLang::CompilerOrchestrator.new.compile_sources(
        source_paths: igdb, out_path: (OUT_DIR / "igdb_core4.igapp").to_s
      )
      check("regression: igdb core-4 flat still ok", status(r) == "ok")

      igmesh = %w[types msg gossip membership antientropy example]
               .map { |f| (LAB_APPS / "igmesh/#{f}.ig").to_s }
      r = IgniterLang::CompilerOrchestrator.new.compile_sources(
        source_paths: igmesh, out_path: (OUT_DIR / "igmesh_pure.igapp").to_s
      )
      check("regression: igmesh pure set flat still ok", status(r) == "ok")
    else
      puts "SKIP  lab apps dir not found (#{LAB_APPS}) — app regression skipped"
    end

    failed = CHECKS.reject { |(_, ok)| ok }
    puts "#{CHECKS.size - failed.size}/#{CHECKS.size} checks passed"
    exit(failed.empty? ? 0 : 1)
  end
end

StdlibImportFlatValidationP1Proof.run
