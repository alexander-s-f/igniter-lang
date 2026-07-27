#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/effect_iteration_helper_proof/effect_iteration_helper_proof.rb
#
# LANG-EFFECT-ITERATION-HELPER-WRAP-FAIL-CLOSED-P3 — Ruby canon slice.
#
# The P2 direct-IO placement fence, lifted interprocedurally: an app-local helper
# `def` whose call graph transitively reaches a host-IO sink (stdlib.IO.* /
# stdlib.net.request / stdlib.ledger.*) may not be called from an ITERATION context — a collection-HOF
# lambda body, or a managed-loop body (finite or budgeted). One root OOF-EC6 teaches
# the pure-Collection[EffectIntent] + single-invoke rewrite. The reachability decision
# is the shared deterministic transitive summary (compute_io_helper_summary) built over
# the SAME fn_extract_all_calls call graph + tarjan_sccs used by the OOF-L4 gate.
#
# Ownership notes (honest dispositions — see packet §Ruby def ownership):
#   * In a HOF-lambda position, Ruby's infer_expr does NOT resolve app-local `def`
#     calls (pre-existing lab-def limitation): a PURE or UNKNOWN helper there is
#     OOF-TY0 "Unknown function", NOT green and NOT OOF-EC6. This card takes over
#     ONLY the IO-reaching case, making the placement law the root and suppressing
#     the derivative OOF-TY0/TY1. Pure/unknown ownership is unchanged.
#   * In a LOOP-BODY position, helper calls are otherwise accepted silently, so a
#     PURE helper there is genuinely green and an IO-reaching helper is the real gap
#     this card closes.

require_relative "../../lib/igniter_lang/parser"
require_relative "../../lib/igniter_lang/classifier"
require_relative "../../lib/igniter_lang/typechecker"

GREEN = "\e[32m"; RED = "\e[31m"; CYAN = "\e[36m"; BOLD = "\e[1m"; RESET = "\e[0m"

def pipeline(src)
  p = IgniterLang::ParsedProgram.parse(src, source_path: "ehelper").to_h
  c = IgniterLang::Classifier.new.classify(p, sample_input: {})
  t = IgniterLang::TypeChecker.new.typecheck(c)
  { parsed: p, classified: c, typed: t }
end

def all_diags(src)
  r = pipeline(src)
  parse = r[:parsed].fetch("parse_errors", []).map { |e| { "rule" => e.fetch("rule", e["code"]), "message" => e["message"] } }
  classify = r[:classified].fetch("contracts").flat_map { |x| x.fetch("oof_log", []).map { |d| { "rule" => d.fetch("rule", d["code"]), "message" => d["message"] } } }
  type = r[:typed].fetch("contracts").flat_map { |x| x.fetch("type_errors", []).map { |d| { "rule" => d.fetch("rule", d["code"]), "message" => d["message"] } } }
  (parse + classify + type)
end

def all_rules(src) = all_diags(src).map { |d| d["rule"] }
def uniq_rules(src) = all_rules(src).sort.uniq
def ec6_messages(src) = all_diags(src).select { |d| d["rule"] == "OOF-EC6" }.map { |d| d["message"] }

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
def m(body) = "module Proof.EffectHelper\n#{body}\n"

# The exact helper-wrap remedy, held BYTE-IDENTICAL to the Rust twin
# (classifier IterIoHit::Helper / effect_call_tests::helper_ec6_message).
def helper_msg(name, locus)
  "helper '#{name}' called inside #{locus} reaches host IO through its call " \
  "graph (a shipped stdlib.IO.* / stdlib.net.request / stdlib.ledger.* sink is transitively " \
  "reachable) — an app-local helper that performs an external effect is not " \
  "allowed in iteration position; build a pure Collection[EffectIntent] and " \
  "perform ONE declaration-position invoke outside the iteration (PROP-050)"
end

# LANG-TYPE-REF-UNRESOLVED-FAIL-CLOSED-P1: use the actual structural return
# type of stdlib.IO.write_text. The retired IoWriteResult placeholder only
# stayed quiet before contract port references became fail-closed.
WRITE_DEF = <<~IG
  def write_one(path: Text, body: Text, io_write: IO.Capability) -> Result[WriteReceipt, IoError] {
    return stdlib.IO.write_text(path, body, io_write)
  }
IG

# ── IO-reaching helper in iteration => ONE OOF-EC6 ───────────────────────────
section "Helper-wrapped host IO in iteration fails closed with ONE OOF-EC6"

MAP_HELPER = m(WRITE_DEF + <<~IG)
  observed contract Flush {
    capability io_write: IO.Capability
    effect write_file using io_write
    input rows: Collection[Text]
    compute receipts = map(rows, (row) -> write_one("rows.log", row, io_write))
    output receipts: Collection[Result[WriteReceipt, IoError]]
  }
IG
check("one-hop helper in map lambda => exactly [OOF-EC6]") { all_rules(MAP_HELPER) == ["OOF-EC6"] }
check("  wording names helper + locus + host IO + rewrite (byte-identical to Rust)") do
  ec6_messages(MAP_HELPER) == [helper_msg("write_one", "a lambda body in compute 'receipts'")]
end

FOR_HELPER = m(WRITE_DEF + <<~IG)
  observed contract Flush {
    capability io_write: IO.Capability
    effect write_file using io_write
    input rows: Collection[Text]
    for Step row in rows {
      lead wrote: Integer = 0
      compute wrote = if is_ok(write_one("rows.log", row, io_write)) { wrote + 1 } else { wrote }
    }
    output rows: Collection[Text]
  }
IG
check("one-hop helper in finite for-loop body => [OOF-EC6]") { uniq_rules(FOR_HELPER) == ["OOF-EC6"] }
check("  loop-body wording names loop locus") do
  ec6_messages(FOR_HELPER) == [helper_msg("write_one", "loop body 'Step'")]
end

BUDGETED_HELPER = m(WRITE_DEF + <<~IG)
  observed contract Flush {
    capability io_write: IO.Capability
    effect write_file using io_write
    input n : Integer
    compute offsets = range(0, n)
    loop Flush off in offsets max_steps: 10 {
      lead wrote: Integer = 0
      compute wrote = if is_ok(write_one("rows.log", "x", io_write)) { wrote + 1 } else { wrote }
    }
    output n : Integer
  }
IG
check("one-hop helper in budgeted loop body => [OOF-EC6]") { uniq_rules(BUDGETED_HELPER) == ["OOF-EC6"] }

TWO_HOP = m(<<~IG)
  def sink(p: Text, io_read: IO.Capability) -> Result[Text, IoError] {
    return stdlib.IO.read_text(p, io_read)
  }
  def outer(p: Text, io_read: IO.Capability) -> Result[Text, IoError] {
    return sink(p, io_read)
  }
  observed contract Reader {
    capability io_read: IO.Capability
    effect read_file using io_read
    input paths: Collection[Text]
    compute contents = map(paths, (p) -> outer(p, io_read))
    output contents: Collection[Result[Text, IoError]]
  }
IG
check("two-hop helper chain (outer -> sink -> read) => [OOF-EC6]") { uniq_rules(TWO_HOP) == ["OOF-EC6"] }
check("  names the directly-called helper 'outer'") do
  ec6_messages(TWO_HOP) == [helper_msg("outer", "a lambda body in compute 'contents'")]
end

CYCLIC = m(<<~IG)
  def ping(p: Text, io_read: IO.Capability) -> Result[Text, IoError] decreases fuel {
    let x = stdlib.IO.read_text(p, io_read)
    pong(p, io_read)
  }
  def pong(p: Text, io_read: IO.Capability) -> Result[Text, IoError] decreases fuel {
    ping(p, io_read)
  }
  observed contract Reader {
    capability io_read: IO.Capability
    effect read_file using io_read
    input paths: Collection[Text]
    compute contents = map(paths, (p) -> pong(p, io_read))
    output contents: Collection[Result[Text, IoError]]
  }
IG
check("cyclic helper SCC (ping<->pong, one IO member) => [OOF-EC6], terminates") { uniq_rules(CYCLIC) == ["OOF-EC6"] }
check("  called through non-IO SCC member 'pong', still refused (shared summary)") do
  ec6_messages(CYCLIC) == [helper_msg("pong", "a lambda body in compute 'contents'")]
end
check("  deterministic across runs") { uniq_rules(CYCLIC) == uniq_rules(CYCLIC) }

NET_TYPES = <<~IG
  type NetHeader { name: Text, value: Text }
  type NetRequest { method: Text, url: Text, headers: Collection[NetHeader], body: Text }
  type NetResponse { status: Integer, headers: Collection[NetHeader], body: Text, truncated: Bool }
  variant NetError {
    Refused { reason: Text }
    TooLarge { limit: Integer }
    Failed { reason: Text }
    Unknown { reason: Text }
  }
IG

NET_HELPER = m(NET_TYPES + <<~IG)
  def hit(req: NetRequest, net_cap: IO.NetworkCapability) -> Result[NetResponse, NetError] {
    return stdlib.net.request(req, net_cap)
  }
  observed contract Caller {
    capability net_cap: IO.NetworkCapability
    effect connect using net_cap
    input reqs: Collection[NetRequest]
    compute rs = map(reqs, (req) -> hit(req, net_cap))
    output rs: Collection[Result[NetResponse, NetError]]
  }
IG
check("net.request through helper in map lambda => [OOF-EC6], exact Rust-parity wording") do
  all_rules(NET_HELPER) == ["OOF-EC6"] &&
    ec6_messages(NET_HELPER) == [helper_msg("hit", "a lambda body in compute 'rs'")]
end

LEDGER_TYPES = <<~IG
  type LedgerLatestRequest { store: Text, key: Text }
  type LedgerFact {
    store: Text
    id: Text
    key: Text
    value_canonical_json: Text
    schema_version: Integer
    producer: Text
    value_hash: Text
    seq_id: Integer
  }
  variant LedgerError {
    Conflict { existing_key: Text, existing_value_hash: Text }
    Unavailable { reason: Text }
    Failed { reason: Text, retryable: Bool }
    CompactionGap { compaction_floor: Integer }
  }
IG

LEDGER_HELPER = m(LEDGER_TYPES + <<~IG)
  def lookup(req: LedgerLatestRequest, ledger_cap: IO.LedgerCapability) -> Result[Option[LedgerFact], LedgerError] {
    return stdlib.ledger.latest(req, ledger_cap)
  }
  observed contract Caller {
    capability ledger_cap: IO.LedgerCapability
    effect read_file using ledger_cap
    input reqs: Collection[LedgerLatestRequest]
    compute rs = map(reqs, (req) -> lookup(req, ledger_cap))
    output rs: Collection[Result[Option[LedgerFact], LedgerError]]
  }
IG
check("ledger.latest through helper in map lambda => [OOF-EC6], exact Rust-parity wording") do
  all_rules(LEDGER_HELPER) == ["OOF-EC6"] &&
    ec6_messages(LEDGER_HELPER) == [helper_msg("lookup", "a lambda body in compute 'rs'")]
end

# ── Controls / ownership boundaries ──────────────────────────────────────────
section "Controls and preserved ownership"

PURE_LOOP_HELPER = m(<<~IG)
  def bump(x: Integer) -> Integer {
    return x + 1
  }
  observed contract L {
    input xs: Collection[Integer]
    for Step x in xs {
      lead total: Integer = 0
      compute total = total + bump(x)
    }
    output xs: Collection[Integer]
  }
IG
check("pure helper in LOOP body stays green") { uniq_rules(PURE_LOOP_HELPER).empty? }

TOP_LEVEL = m(WRITE_DEF + <<~IG)
  observed contract Flush {
    capability io_write: IO.Capability
    effect write_file using io_write
    input row: Text
    compute r = write_one("rows.log", row, io_write)
    output r: Result[WriteReceipt, IoError]
  }
IG
check("top-level IO-helper call does NOT receive OOF-EC6") { !uniq_rules(TOP_LEVEL).include?("OOF-EC6") }

UNKNOWN_HELPER = m(<<~IG)
  observed contract M {
    input xs: Collection[Integer]
    compute ys = map(xs, (x) -> nonexistent(x))
    output ys: Collection[Integer]
  }
IG
INDEPENDENT_PORT_ERROR = m(WRITE_DEF + <<~IG)
  observed contract Flush {
    capability io_write: IO.Capability
    effect write_file using io_write
    input rows: Collection[Text]
    input bad: MissingType
    compute receipts = map(rows, (row) -> write_one("rows.log", row, io_write))
    output receipts: Collection[Result[WriteReceipt, IoError]]
  }
IG
check("unknown helper keeps OOF-TY0; EC6 does not suppress an independent port OOF-TY0") do
  rs = uniq_rules(UNKNOWN_HELPER)
  independent = all_diags(INDEPENDENT_PORT_ERROR)
  missing_type = {
    "rule" => "OOF-TY0",
    "message" => "Unresolved type reference 'MissingType' in input 'bad' of contract 'Flush'"
  }
  rs.include?("OOF-TY0") && !rs.include?("OOF-EC6") &&
    independent.count { |d| d["rule"] == "OOF-EC6" } == 1 &&
    independent.count { |d| d == missing_type } == 1 && independent.size == 2
end

# ── P2 direct-IO regressions remain green ────────────────────────────────────
section "P2 direct-IO placement law regressions"

DIRECT_MAP = m(<<~IG)
  observed contract MapRead {
    capability io_read: IO.Capability
    effect read_file using io_read
    input paths: Collection[String]
    compute contents = map(paths, (p) -> stdlib.IO.read_text(p, io_read))
    output contents: Collection[Result[String, IoError]]
  }
IG
check("direct read_text in map lambda still => [OOF-EC6] (P2)") { uniq_rules(DIRECT_MAP) == ["OOF-EC6"] }

INVOKE_IN_LOOP = m(<<~IG)
  observed contract IL {
    capability io_write: IO.Capability
    effect write_file using io_write
    input reqs: Collection[Text]
    compute offsets = range(0, 3)
    loop Flush off in offsets max_steps: 10 {
      lead done: Integer = 0
      invoke r = Callee(off) using io_write
    }
    output reqs: Collection[Text]
  }
IG
check("invoke inside loop body still => OOF-EC6 (P2/PROP-050)") { uniq_rules(INVOKE_IN_LOOP).include?("OOF-EC6") }

# ── Summary ──────────────────────────────────────────────────────────────────
puts "\n#{BOLD}#{RESULTS.count(true)}/#{RESULTS.size} checks passed#{RESET}"
exit(RESULTS.all? ? 0 : 1)
