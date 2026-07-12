#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Isolation helper for LANG-RUBY-UNKNOWN-FIELD-ASSIGNABILITY-PARITY-P1's before/after proof.
#
# Ruby's `require` caches a file's class/method definitions for the lifetime of the process —
# git-stashing lib/igniter_lang/typechecker.rb on disk and re-running compile_sources IN THE SAME
# PROCESS has NO EFFECT (confirmed empirically: a same-process before/after around a git stash
# returns identical "ok" for map_get_string even when the on-disk file is pristine, because the
# patched class definition is already loaded into memory). A genuine "before" run needs a FRESH
# OS process that requires igniter_lang from whatever is currently on disk. This script IS that
# fresh process — the proof driver shells out to it via Open3 twice (once with the tree stashed
# to pristine, once with the patch restored) and diffs the two JSON results.
#
# Usage: ruby run_compile_subprocess.rb <source_path_1> [<source_path_2> ...]
# Prints the CompilerOrchestrator#compile_sources result as one line of JSON on stdout.

require "json"

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "igniter_lang"
require "igniter_lang/compiler_orchestrator"
require "tmpdir"

source_paths = ARGV
raise "usage: run_compile_subprocess.rb <source_path...>" if source_paths.empty?

Dir.mktmpdir("unknown-field-subprocess") do |dir|
  result = IgniterLang::CompilerOrchestrator.new.compile_sources(
    source_paths: source_paths,
    out_path: File.join(dir, "out.igapp")
  )
  puts JSON.generate(result)
end
