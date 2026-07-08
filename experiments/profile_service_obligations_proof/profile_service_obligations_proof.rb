#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/profile_service_obligations_proof/profile_service_obligations_proof.rb
#
# LANG-PROFILE-SERVICE-OBLIGATIONS-P51 (ch11 §11.3) — graduates the service-loop
# obligation PROFILE properties from HELD, now that `service` obligation clauses
# are live (P50). A profile may declare `heartbeat`/`checkpoint`/`cancellation`:
# `required | optional | none`. A `required` obligation forces a bound contract
# to DECLARE that obligation clause; missing ⇒ OOF-PROF7 (hard). `optional`/`none`
# impose nothing. Compile-time declaration policy (Covenant P10) — grants no
# runtime liveness (the P50 boundary). The genuinely-new capability is
# `checkpoint: required` (P50 leaves checkpoint optional on a bare service).
# Malformed mode fails closed (OOF-PROF6). max_step_latency ceiling is DEFERRED
# (needs duration ordering, like max_reversibility was its own card). Ruby-canon.

require "json"

require_relative "../../lib/igniter_lang/parser"
require_relative "../../lib/igniter_lang/classifier"
require_relative "../../lib/igniter_lang/typechecker"

GREEN = "\e[32m"; RED = "\e[31m"; CYAN = "\e[36m"; BOLD = "\e[1m"; RESET = "\e[0m"

def parse(src) = IgniterLang::ParsedProgram.parse(src, source_path: "svcob").to_h
def classify(src) = IgniterLang::Classifier.new.classify(parse(src), sample_input: {})
def typed(src) = IgniterLang::TypeChecker.new.typecheck(classify(src))

def contract_oofs(classified, name, rule)
  c = classified.fetch("contracts").find { |x| x.fetch("name") == name }
  c.fetch("oof_log", []).select { |d| d.fetch("rule", d["code"]) == rule }
end

RESULTS = []
def check(label, &b)
  r = b.call
  puts "  #{r ? GREEN : RED}[#{r ? 'PASS' : 'FAIL'}]#{RESET} #{label}"
  RESULTS << r
rescue => e
  puts "  #{RED}[ERROR]#{RESET} #{label}: #{e.message}"; RESULTS << false
end
def section(t) = puts("\n#{CYAN}#{BOLD}── #{t} ──#{RESET}")

# a service contract, optionally declaring `checkpoint`.
def svc(checkpoint: false)
  cp = checkpoint ? "  checkpoint every 1.minute\n" : ""
  <<~C
    service contract Watch via sp {
      heartbeat every 10.seconds
      cancellation required
      max_step_latency 2.seconds
    #{cp}}
  C
end

def prog(profile_body, contract)
  "module Proof.SvcOb\nprofile sp { #{profile_body} }\n#{contract}"
end

puts "#{BOLD}#{CYAN}Profile service-obligations proof (LANG-PROFILE-SERVICE-OBLIGATIONS-P51)#{RESET}"
puts "Path: igniter-lang/experiments/profile_service_obligations_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "AST — obligations stored on the profile"

check("AST-1: `checkpoint: required` stored under service_obligations") do
  parse(prog("loop: service  checkpoint: required", svc)).fetch("profiles").first
    .fetch("service_obligations", {})["checkpoint"] == "required"
end

check("AST-2: all three modes parse (required/optional/none)") do
  p = parse(prog("heartbeat: required  checkpoint: optional  cancellation: none", svc))
    .fetch("profiles").first.fetch("service_obligations", {})
  p == { "heartbeat" => "required", "checkpoint" => "optional", "cancellation" => "none" }
end

# ══════════════════════════════════════════════════════════════════════════════
section "OOF-PROF7 — a required obligation the bound contract omits (hard error)"

check("PROF7-1: `checkpoint: required` + service without checkpoint ⇒ OOF-PROF7 (the new capability)") do
  contract_oofs(classify(prog("loop: service  checkpoint: required", svc(checkpoint: false))),
                "Watch", "OOF-PROF7").any?
end

check("PROF7-2: OOF-PROF7 is a HARD error — contract blocked") do
  typed(prog("loop: service  checkpoint: required", svc(checkpoint: false)))
    .fetch("contracts").find { |x| x.fetch("name") == "Watch" }.fetch("status") == "blocked"
end

check("PROF7-3: message names contract, obligation, and profile") do
  m = contract_oofs(classify(prog("checkpoint: required", svc(checkpoint: false))),
                    "Watch", "OOF-PROF7").first.fetch("message")
  m.include?("Watch") && m.include?("checkpoint") && m.include?("sp")
end

# ══════════════════════════════════════════════════════════════════════════════
section "Clean — obligation satisfied, optional/none, no via"

check("CLEAN-1: `checkpoint: required` + service WITH checkpoint ⇒ clean") do
  contract_oofs(classify(prog("loop: service  checkpoint: required", svc(checkpoint: true))),
                "Watch", "OOF-PROF7").empty?
end

check("CLEAN-2: `checkpoint: optional` ⇒ no obligation (clean without checkpoint)") do
  contract_oofs(classify(prog("checkpoint: optional", svc(checkpoint: false))),
                "Watch", "OOF-PROF7").empty?
end

check("CLEAN-3: `checkpoint: none` ⇒ no obligation") do
  contract_oofs(classify(prog("checkpoint: none", svc(checkpoint: false))),
                "Watch", "OOF-PROF7").empty?
end

check("CLEAN-4: `heartbeat: required` is satisfied (service already declares heartbeat via P50)") do
  contract_oofs(classify(prog("loop: service  heartbeat: required", svc(checkpoint: false))),
                "Watch", "OOF-PROF7").empty?
end

check("CLEAN-5: absent service_obligations ⇒ no constraint") do
  contract_oofs(classify(prog("loop: service", svc(checkpoint: false))), "Watch", "OOF-PROF7").empty?
end

check("CLEAN-6: contract WITHOUT `via` ⇒ obligation does not apply") do
  src = <<~IG
    module Proof.SvcOb
    profile sp { checkpoint: required }
    service contract Unbound {
      heartbeat every 10.seconds
      cancellation required
      max_step_latency 2.seconds
    }
  IG
  contract_oofs(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}),
                "Unbound", "OOF-PROF7").empty?
end

# ══════════════════════════════════════════════════════════════════════════════
section "Malformed mode fails closed"

check("MAL-1: `checkpoint: sometimes` (unknown mode) ⇒ OOF-PROF6, not stored") do
  p = parse(prog("checkpoint: sometimes", svc))
  p.fetch("parse_errors").any? { |e| e.fetch("rule", e["code"]) == "OOF-PROF6" } &&
    !(p.fetch("profiles").first.fetch("service_obligations", {}).key?("checkpoint"))
end

check("MAL-2: refused obligation cannot spuriously fire OOF-PROF7") do
  contract_oofs(classify(prog("checkpoint: sometimes", svc(checkpoint: false))),
                "Watch", "OOF-PROF7").empty?
end

# ══════════════════════════════════════════════════════════════════════════════
section "Boundary + coexistence"

check("BOUND-1: OOF-PROF7 grants no runtime liveness — obligation clause mints no grant node") do
  # a satisfied checkpoint obligation adds no alive/scheduler node; declaration != enforcement.
  t = typed(prog("checkpoint: required", svc(checkpoint: true)))
  kinds = t.fetch("contracts").find { |x| x.fetch("name") == "Watch" }.fetch("declarations", []).map { |d| d.fetch("kind", "") }
  %w[alive liveness scheduler].none? { |k| kinds.include?(k) }
end

check("REG-1: loop:service + service obligations coexist; fully-satisfied contract clean") do
  src = prog("loop: service  heartbeat: required  cancellation: required  checkpoint: required",
             svc(checkpoint: true))
  c = IgniterLang::Classifier.new.classify(parse(src), sample_input: {})
  %w[OOF-PROF3 OOF-PROF7 OOF-SL1 OOF-SL2 OOF-SL3].all? { |r| contract_oofs(c, "Watch", r).empty? }
end

passed = RESULTS.count(&:itself); total = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
