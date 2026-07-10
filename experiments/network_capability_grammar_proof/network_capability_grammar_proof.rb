#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/network_capability_grammar_proof/network_capability_grammar_proof.rb
#
# LANG-NETWORK-CAPABILITY-GRAMMAR-P2 — structured `IO.NetworkCapability`
# declaration grammar + normalized `network_capability_v1` policy metadata.
#
# DECLARED POLICY METADATA ONLY (authority boundary): nothing here opens a
# socket, adds a stdlib sink, or changes passport authority. The emitted
# object carries the explicit marker `enforcement: "host_required"`.
#
# Proves (mirror of igniter-compiler/tests/network_capability_grammar_tests.rs):
#   (1) bare `capability net : IO.NetworkCapability` stays byte-identical —
#       no new keys anywhere in the SIR;
#   (2) the structured declaration parses and emits the normalized object
#       under the capability slot in effect_surface_v1;
#   (3) every static rule fails closed with its bounded OOF-NET* code
#       (OOF-NET1..OOF-NET10) and the EXACT message string the Rust lab
#       compiler emits (dual-toolchain diagnostic parity anchor);
#   (4) fail-closed: a violating block leaves NO network_attributes on the
#       parsed declaration;
#   (5) the metadata survives a multifile (MultifileResolver) compile.

require "json"

require_relative "../../lib/igniter_lang/parser"
require_relative "../../lib/igniter_lang/classifier"
require_relative "../../lib/igniter_lang/typechecker"
require_relative "../../lib/igniter_lang/semanticir_emitter"
require_relative "../../lib/igniter_lang/multifile_resolver"

GREEN = "\e[32m"
RED   = "\e[31m"
CYAN  = "\e[36m"
BOLD  = "\e[1m"
RESET = "\e[0m"

FIXTURE_DIR = File.join(__dir__, "fixtures")

def parse_fixture(fixture_name)
  src = File.read(File.join(FIXTURE_DIR, "#{fixture_name}.ig"))
  IgniterLang::ParsedProgram.parse(src, source_path: fixture_name).to_h
end

def compile(fixture_name)
  parsed     = parse_fixture(fixture_name)
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  typed      = IgniterLang::TypeChecker.new.typecheck(classified)
  sir        = IgniterLang::SemanticIREmitter.new.emit_typed(typed)
  { parsed: parsed, classified: classified, typed: typed, sir: sir }
end

RESULTS = []

def check(label, &block)
  result = block.call
  colour = result ? GREEN : RED
  puts "  #{colour}[#{result ? "PASS" : "FAIL"}]#{RESET} #{label}"
  RESULTS << { label: label, pass: result }
rescue => e
  puts "  #{RED}[ERROR]#{RESET} #{label}: #{e.message}"
  RESULTS << { label: label, pass: false }
end

def section(title)
  puts "\n#{CYAN}#{BOLD}── #{title} ──#{RESET}"
end

def errors_of(parsed)
  parsed.fetch("parse_errors", []).map { |e| [e["rule"], e["message"]] }
end

def binding_of(result)
  result[:sir].dig("semantic_ir", "contracts", 0, "effect_surface", "capability_bindings", 0)
end

EXPECTED_NORMALIZED = {
  "kind"            => "network_capability_v1",
  "protocol"        => "tcp",
  "allowed_hosts"   => ["127.0.0.1", "localhost"],
  "port_lo"         => 8000,
  "port_hi"         => 9000,
  "loopback_only"   => true,
  "connect_allowed" => true,
  "listen_allowed"  => false,
  "tls_required"    => false,
  "enforcement"     => "host_required"
}.freeze

puts "#{BOLD}#{CYAN}Network capability grammar proof (LANG-NETWORK-CAPABILITY-GRAMMAR-P2)#{RESET}"
puts "Path: igniter-lang/experiments/network_capability_grammar_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "NETCAP-BARE — bare declaration is unchanged (no new keys)"
# ══════════════════════════════════════════════════════════════════════════════

bare = compile("netcap_bare")

check("BARE-1: bare capability parses clean") do
  bare[:parsed].fetch("parse_errors", []).empty?
end

check("BARE-2: no network_attributes key on the parsed declaration") do
  cap = bare[:parsed].fetch("contracts").first.fetch("body").find { |d| d["kind"] == "capability" }
  !cap.key?("network_attributes")
end

check("BARE-3: no network_capability key in the emitted binding") do
  !binding_of(bare).key?("network_capability")
end

# ══════════════════════════════════════════════════════════════════════════════
section "NETCAP-EMIT — structured declaration parses + normalized emission"
# ══════════════════════════════════════════════════════════════════════════════

basic = compile("netcap_basic")

check("EMIT-1: target declaration parses clean") do
  basic[:parsed].fetch("parse_errors", []).empty?
end

check("EMIT-2: effect_surface binding carries the exact network_capability_v1 object") do
  binding_of(basic)["network_capability"] == EXPECTED_NORMALIZED
end

check("EMIT-3: enforcement marker is host_required (declaration ≠ enforcement)") do
  binding_of(basic).dig("network_capability", "enforcement") == "host_required"
end

check("EMIT-4: external-host variant (loopback_only:false, tls_required:true) compiles clean") do
  ext = compile("netcap_external_ok")
  nc  = binding_of(ext)["network_capability"]
  ext[:parsed].fetch("parse_errors", []).empty? &&
    nc["allowed_hosts"] == ["api.example.com"] && nc["tls_required"] == true
end

# ══════════════════════════════════════════════════════════════════════════════
section "NETCAP-RULES — OOF-NET1..OOF-NET10 fail closed with exact messages"
# ══════════════════════════════════════════════════════════════════════════════

RULE_CASES = {
  "netcap_net1_wrong_type" => ["OOF-NET1",
    "network capability attributes are only allowed on IO.NetworkCapability (got 'IO.Capability')"],
  "netcap_net2_unknown" => ["OOF-NET2",
    "unknown network capability attribute 'frobnicate'"],
  "netcap_net3_duplicate" => ["OOF-NET3",
    "duplicate network capability attribute 'protocol'"],
  "netcap_net4_missing" => ["OOF-NET4",
    "missing required network capability attribute 'port_hi'"],
  "netcap_net5_wrong_typed" => ["OOF-NET5",
    "network capability attribute 'protocol' must be a literal string"],
  "netcap_net6_ports" => ["OOF-NET6",
    "network capability port range invalid: port_lo and port_hi must be within 1..65535 and port_lo <= port_hi"],
  "netcap_net7_dead_grant" => ["OOF-NET7",
    "dead network capability grant: connect_allowed and listen_allowed are both false"],
  "netcap_net8_loopback" => ["OOF-NET8",
    "loopback_only:true cannot be weakened by non-loopback allowed_hosts entry 'api.example.com'"],
  "netcap_net8_wildcard" => ["OOF-NET8",
    "loopback_only:true cannot be weakened by non-loopback allowed_hosts entry '*'"],
  "netcap_net8_prefix_spoof" => ["OOF-NET8",
    "loopback_only:true cannot be weakened by non-loopback allowed_hosts entry '127.evil.example'"],
  "netcap_net9_http" => ["OOF-NET9",
    "protocol \"http\" is an application operation over tcp; declare protocol: \"tcp\" (transport vocabulary per igniter-machine HttpCapabilityExecutor)"],
  "netcap_net9_udp" => ["OOF-NET9",
    "unsupported network capability protocol 'udp' (v0 supports \"tcp\" only; UDP is not implied)"],
  "netcap_net10_userinfo" => ["OOF-NET10",
    "network capability allowed_hosts entry 'user@127.0.0.1' must be a bare host literal (no scheme, userinfo, secrets, or whitespace)"]
}.freeze

RULE_CASES.each do |fixture, (rule, message)|
  check("#{rule}: #{fixture} fires exactly [#{rule}] with the parity-locked message") do
    errors_of(parse_fixture(fixture)) == [[rule, message]]
  end
end

check("RULES-NO-CASCADE: wrong-typed field does NOT also fire OOF-NET4") do
  rules = errors_of(parse_fixture("netcap_net5_wrong_typed")).map(&:first)
  rules == ["OOF-NET5"]
end

check("RULES-FAIL-CLOSED: violating block leaves NO network_attributes on the decl") do
  parsed = parse_fixture("netcap_net7_dead_grant")
  cap = parsed.fetch("contracts").first.fetch("body").find { |d| d["kind"] == "capability" }
  !cap.key?("network_attributes")
end

# ══════════════════════════════════════════════════════════════════════════════
section "NETCAP-MULTIFILE — metadata survives a MultifileResolver compile"
# ══════════════════════════════════════════════════════════════════════════════

check("MF-1: multifile merge + emit carries network_capability_v1 for SendPing") do
  resolved = IgniterLang::MultifileResolver.new.resolve([
    File.join(FIXTURE_DIR, "netcap_mf_helper.ig"),
    File.join(FIXTURE_DIR, "netcap_mf_main.ig")
  ])
  raise "multifile resolve failed: #{resolved["diagnostics"].inspect}" unless resolved["ok"]

  classified = IgniterLang::Classifier.new.classify(resolved.fetch("parsed_program"), sample_input: {})
  typed      = IgniterLang::TypeChecker.new.typecheck(classified)
  sir        = IgniterLang::SemanticIREmitter.new.emit_typed(typed)
  contract   = sir.dig("semantic_ir", "contracts").find { |c| c["contract_name"] == "SendPing" }
  nc = contract.dig("effect_surface", "capability_bindings", 0, "network_capability")
  nc == EXPECTED_NORMALIZED
end

# ══════════════════════════════════════════════════════════════════════════════

failed = RESULTS.reject { |r| r[:pass] }
puts "\n#{BOLD}#{failed.empty? ? GREEN : RED}#{RESULTS.size - failed.size}/#{RESULTS.size} checks passed#{RESET}"
failed.each { |r| puts "  #{RED}FAILED:#{RESET} #{r[:label]}" }
exit(failed.empty? ? 0 : 1)
