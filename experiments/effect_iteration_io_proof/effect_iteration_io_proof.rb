#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/effect_iteration_io_proof/effect_iteration_io_proof.rb
#
# LANG-EFFECT-ITERATION-DIRECT-IO-FAIL-CLOSED-P2 — Ruby canon slice.
#
# A direct host-IO call (stdlib.IO.* / stdlib.net.request) inside an ITERATION
# context — a collection-HOF lambda body, or a managed-loop body (finite or
# budgeted; any nesting, incl. under if/match) — fails closed with ONE root
# OOF-EC6 teaching the pure-Collection[EffectIntent] + single-invoke remedy.
# Controls: top-level direct IO stays green; pure map/loop stay green; the
# existing malformed-invoke / invoke-in-loop OOF-EC6 are untouched.

require_relative "../../lib/igniter_lang/parser"
require_relative "../../lib/igniter_lang/classifier"
require_relative "../../lib/igniter_lang/typechecker"

GREEN = "\e[32m"; RED = "\e[31m"; CYAN = "\e[36m"; BOLD = "\e[1m"; RESET = "\e[0m"

def pipeline(src)
  p = IgniterLang::ParsedProgram.parse(src, source_path: "eiter").to_h
  c = IgniterLang::Classifier.new.classify(p, sample_input: {})
  t = IgniterLang::TypeChecker.new.typecheck(c)
  { parsed: p, classified: c, typed: t }
end

def all_rules(src)
  r = pipeline(src)
  parse = r[:parsed].fetch("parse_errors", []).map { |e| e.fetch("rule", e["code"]) }
  classify = r[:classified].fetch("contracts").flat_map { |x| x.fetch("oof_log", []).map { |d| d.fetch("rule", d["code"]) } }
  type = r[:typed].fetch("contracts").flat_map { |x| x.fetch("type_errors", []).map { |d| d.fetch("rule", d["code"]) } }
  (parse + classify + type)
end

def uniq_rules(src) = all_rules(src).sort.uniq

RESULTS = []
def check(label, &b)
  r = b.call
  puts "  #{r ? GREEN : RED}[#{r ? 'PASS' : 'FAIL'}]#{RESET} #{label}"
  RESULTS << r
rescue => e
  puts "  #{RED}[ERROR]#{RESET} #{label}: #{e.message} @ #{e.backtrace.first}"
  RESULTS << false
end
def section(t) = puts("\n#{CYAN}#{BOLD}── #{t} ──#{RESET}")

def m(body) = "module Proof.EffectIter\n#{body}\n"

# ── Refused shapes: exactly one OOF-EC6, no cascade ──────────────────────────
section "Iteration host-IO fails closed with ONE OOF-EC6"

LOOP_WRITE = m(<<~IG)
  observed contract LoopWrite {
    capability io_write: IO.Capability
    effect write_file using io_write
    input n : Integer
    compute offsets = range(0, n)
    loop Flush off in offsets max_steps: 10 {
      lead wrote : Integer = 0
      compute wrote = if is_ok(stdlib.IO.write_at("p.bin", off, text_to_bytes("L"), io_write)) { wrote + 1 } else { wrote }
    }
    output n : Integer
  }
IG
check("write_at in budgeted loop body => [OOF-EC6]") { uniq_rules(LOOP_WRITE) == ["OOF-EC6"] }

FOR_WRITE = m(<<~IG)
  observed contract ForWrite {
    capability io_write: IO.Capability
    effect write_file using io_write
    input offsets : Collection[Integer]
    for Step off in offsets {
      lead wrote : Integer = 0
      compute wrote = if is_ok(stdlib.IO.write_at("p.bin", off, text_to_bytes("Z"), io_write)) { wrote + 1 } else { wrote }
    }
    output offsets : Collection[Integer]
  }
IG
check("write_at in finite for-loop (different class) => [OOF-EC6]") { uniq_rules(FOR_WRITE) == ["OOF-EC6"] }

MAP_READ = m(<<~IG)
  observed contract MapRead {
    capability io_read: IO.Capability
    effect read_file using io_read
    input paths : Collection[String]
    compute contents = map(paths, (p) -> stdlib.IO.read_text(p, io_read))
    output contents : Collection[Result[String, IoError]]
  }
IG
check("read_text in map lambda => [OOF-EC6]") { uniq_rules(MAP_READ) == ["OOF-EC6"] }

FOLD_WRITE = m(<<~IG)
  observed contract FoldWrite {
    capability io_write: IO.Capability
    effect write_file using io_write
    input items : Collection[String]
    compute total = fold(items, 0, (acc, x) -> if is_ok(stdlib.IO.write_text("f.txt", x, io_write)) { acc + 1 } else { acc })
    output total : Integer
  }
IG
check("write_text in fold lambda => [OOF-EC6]") { uniq_rules(FOLD_WRITE) == ["OOF-EC6"] }

MATCH_LAMBDA = m(<<~IG)
  observed contract MatchLambda {
    capability io_read : IO.Capability
    effect read_file using io_read
    input paths : Collection[String]
    compute r = map(paths, (p) -> match stdlib.IO.exists(p, io_read) { Ok { value } => value, Err { error } => false })
    output r : Collection[Bool]
  }
IG
check("IO nested under match INSIDE lambda => OOF-EC6 present") { uniq_rules(MATCH_LAMBDA).include?("OOF-EC6") }

IF_THEN_LOOP = m(<<~IG)
  observed contract IfThenLoop {
    capability io_write : IO.Capability
    effect write_file using io_write
    input n : Integer
    compute offsets = range(0, n)
    loop Flush off in offsets max_steps: 10 {
      lead wrote : Integer = 0
      compute wrote = if off > 0 { if is_ok(stdlib.IO.write_at("d.bin", off, text_to_bytes("N"), io_write)) { wrote + 1 } else { wrote } } else { wrote }
    }
    output n : Integer
  }
IG
check("IO nested under if-then INSIDE loop body => OOF-EC6 present") { uniq_rules(IF_THEN_LOOP).include?("OOF-EC6") }

NET_LOOP = m(<<~IG)
  observed contract NetLoop {
    capability net_cap : IO.NetworkCapability
    effect connect using net_cap
    input req : NetRequest
    compute idxs = range(0, 3)
    loop Send i in idxs max_steps: 10 {
      lead sent : Integer = 0
      compute sent = if is_ok(stdlib.net.request(req, net_cap)) { sent + 1 } else { sent }
    }
    output req : NetRequest
  }
IG
check("stdlib.net.request in loop => OOF-EC6 present") { uniq_rules(NET_LOOP).include?("OOF-EC6") }

# ── Controls: unaffected ─────────────────────────────────────────────────────
section "Controls stay green / earlier roots preserved"

TOP_WRITE = m(<<~IG)
  observed contract TopWrite {
    capability io_write : IO.Capability
    effect write_file using io_write
    input msg : Text
    compute w = stdlib.IO.write_text("out.txt", msg, io_write)
    output msg : Text
  }
IG
check("top-level direct IO stays green (no OOF-EC6)") { !uniq_rules(TOP_WRITE).include?("OOF-EC6") && uniq_rules(TOP_WRITE).empty? }

PURE_MAP = m(<<~IG)
  pure contract PureMap {
    input xs : Collection[Integer]
    compute ys = map(xs, (x) -> x + 1)
    output ys : Collection[Integer]
  }
IG
check("pure map (no IO) stays green") { uniq_rules(PURE_MAP).empty? }

PURE_LOOP = m(<<~IG)
  observed contract PureLoopOk {
    input offsets : Collection[Integer]
    compute src = range(0, 3)
    loop Acc off in src max_steps: 10 {
      lead total : Integer = 0
      compute total = total + off
    }
    output offsets : Collection[Integer]
  }
IG
check("pure loop body stays green") { uniq_rules(PURE_LOOP).empty? }

# Regression: existing invoke-in-loop OOF-EC6 still fires (not relabelled).
INVOKE_LOOP = <<~IG
  module Proof.EffectIter
  observed contract Callee {
    input n : Integer
    capability io_db_read : IO.Capability
    effect read_file using io_db_read
    compute rows = n
    output rows : Integer
  }
  observed contract C {
    input xs : Collection[Integer]
    input seed : Integer
    capability io_db_read : IO.Capability
    effect read_file using io_db_read
    loop Scan item in xs max_steps: 10 {
      invoke r = Callee(seed) using io_db_read
    }
    output seed : Integer
  }
IG
check("REGRESSION: invoke-in-loop still OOF-EC6") { uniq_rules(INVOKE_LOOP).include?("OOF-EC6") }

# ── summary ──────────────────────────────────────────────────────────────────
pass = RESULTS.count(true); total = RESULTS.size
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{pass == total ? GREEN : RED}PASS #{pass}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(pass == total ? 0 : 1)
