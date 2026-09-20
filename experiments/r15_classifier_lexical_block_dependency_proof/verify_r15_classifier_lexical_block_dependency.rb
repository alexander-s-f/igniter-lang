#!/usr/bin/env ruby
# frozen_string_literal: true

# LANG-CLASSIFIER-LEXICAL-BLOCK-DEPENDENCY-IMPLEMENTATION-R15 — Canon permanent proof.
#
# The classifier's free-name pass (`expr_refs` / `block_refs`) is ONE ordered lexical walk. Before R15 it
#   * walked a lambda `block`'s tail only (its statements are an Array, and Array children were skipped), so a
#     fresh block `let` was an "Unresolved symbol" and an initializer's real outer read / missing name was lost;
#   * bound no `let` at all in a branch block, and skipped array items and match arms entirely.
# This proof drives the classifier OWNER directly (parse -> sugar -> classify), so the typechecker's ordered
# scoping cannot hide a classifier defect, and the full compile for the artifact-level facts:
#   A. fresh / ordered / nested lets are binders; the outer reads are the dependencies;
#   B. an initializer is read BEFORE its own name binds (`let k = k + 1` depends on the outer k; a fresh
#      `let d = d + 1` is unresolved); a same-spelled local that never reads the outer name is no dependency;
#   C. locals do not reach a sibling branch / arm, the enclosing block or a later declaration; pattern binders
#      scope their own arm; a name read before its `let` is unresolved, with NO false report for bound locals;
#   D. array items, record / variant fields and match arms are visited;
#   E. a useful UI-construction program (map-built control list, fold-built card layout, fresh locals) compiles;
#   F. the reserved `__seq__` binder law and the stream-direct-use law (OOF-S4) still refuse;
#   G. a node is identified by its `kind`, never by its keys: user field names spelled like AST keys are fields.
# Expected sets are hand-derived literals; let-ful programs are compared with a let-free reference formulation.
# Values are executed by the Lab packet proofs/lang-classifier-lexical-block-dependency-implementation-r15.

require "json"
require "pathname"
require "tmpdir"

HERE = Pathname.new(__FILE__).expand_path.dirname
ROOT = HERE.join("../..").expand_path
LIB = ROOT.join("lib").to_s
$LOAD_PATH.unshift(LIB) unless $LOAD_PATH.include?(LIB)
require "igniter_lang"

$pass = 0
$fail = 0

def check(name, ok, detail = "")
  if ok
    $pass += 1
    puts "PASS #{name}"
  else
    $fail += 1
    puts "FAIL #{name} #{detail}"
  end
end

# A classifier that CRASHES must print FAIL verdicts, not end the proof (independent re-check RC3): `classify`
# rescues, and a crashed classification answers every lookup below with a value no check accepts.

# The classifier owner alone: the orchestrator's own pre-classify order (parse, constructor + call sugar).
def classify(source)
  parsed = IgniterLang::ParsedProgram.parse(source, source_path: "r15.ig").to_h
  raise "parse errors: #{parsed.fetch("parse_errors").inspect}" unless parsed.fetch("parse_errors").empty?

  IgniterLang::DerivedConstructorSugar.lower!(parsed)
  IgniterLang::ContractCallSugar.lower!(parsed)
  begin
    IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  rescue StandardError => e
    { "contracts" => [], "crash" => "#{e.class}: #{e.message}" }
  end
end

# A crashed classification answers every question with a value no check accepts.
def contract(classified, name)
  return { "declarations" => [], "oof_log" => [{ "rule" => "CRASH", "message" => classified["crash"] }] } if classified["crash"]

  classified.fetch("contracts").find { |c| c.fetch("name") == name } || raise("contract #{name}")
end

def deps(classified, node, contract_name = "O")
  decl = contract(classified, contract_name).fetch("declarations")
    .find { |d| d.fetch("name") == node && %w[compute fold_stream].include?(d.fetch("kind")) }
  decl ? decl.fetch("deps").sort : ["<no declaration: #{classified["crash"]}>"]
end

def unresolved(classified, contract_name = "O")
  log = contract(classified, contract_name).fetch("oof_log")
  return ["<#{classified["crash"]}>"] if classified["crash"]

  log.select { |d| d.fetch("rule") == "OOF-P1" }.map { |d| d.fetch("message").sub("Unresolved symbol: ", "") }.uniq.sort
end

def compile(source)
  Dir.mktmpdir("r15canon") do |dir|
    src = File.join(dir, "m.ig")
    File.write(src, source)
    out = File.join(dir, "out.igapp")
    result = IgniterLang::CompilerOrchestrator.new.compile_sources(source_paths: [src], out_path: out)
    diags = result.dig("compilation_report", "diagnostics") || result["diagnostics"] || []
    sir_path = File.join(out, "semantic_ir_program.json")
    [result["status"], diags.map { |d| d["rule"] }.uniq.sort, File.exist?(sir_path) ? JSON.parse(File.read(sir_path)) : nil]
  end
end

HEAD = "  input a : Integer\n  input flag : Bool\n  input xs : Collection[Integer]\n  input ys : Collection[Integer]\n  compute k : Integer = a * 2\n"

def o(decl, node, type = "Integer")
  "module R15.T\n\npure contract O {\n#{HEAD}#{decl}\n  output #{node} : #{type}\n}\n"
end

def same_deps(name, letful, reference, node, want, type = "Integer")
  { "let-ful" => letful, "reference" => reference }.each do |tag, decl|
    c = classify(o(decl, node, type))
    check("#{name} (#{tag})", unresolved(c).empty? && deps(c, node) == want.sort, "unresolved=#{unresolved(c).inspect} deps=#{deps(c, node).inspect}")
  end
end

# A. fresh / ordered / nested lets
same_deps("A1 fresh ordered lets in a fold callback",
          "  compute total : Integer = fold(xs, 0, (acc, x) -> {\n      let d = x * 2\n      let e = d + k\n      acc + e\n    })",
          "  compute total : Integer = fold(xs, 0, (acc, x) -> acc + ((x * 2) + k))", "total", %w[k xs])
same_deps("A2 fresh branch-local let in a fold callback",
          "  compute total : Integer = fold(xs, 0, (acc, x) -> if x > 1 { let d = x * 2\n      acc + d } else { acc })",
          "  compute total : Integer = fold(xs, 0, (acc, x) -> if x > 1 { acc + (x * 2) } else { acc })", "total", %w[xs])
same_deps("A3 nested capture and parameter shadow",
          "  compute rows : Collection[Integer] = map(xs, x -> {\n      let base = x + k\n      fold(ys, 0, (acc, x) -> {\n        let t = x + base\n        acc + t\n      })\n    })",
          "  compute rows : Collection[Integer] = map(xs, x -> fold(ys, 0, (acc, y) -> acc + (y + (x + k))))", "rows", %w[k xs ys], "Collection[Integer]")

# B. initializer scope and same-spelling
same_deps("B1 branch initializer reads the OUTER k before binding the local k",
          "  compute r : Integer = if flag { let k = k + 1\n      k * 3 } else { 0 }",
          "  compute r : Integer = if flag { (k + 1) * 3 } else { 0 }", "r", %w[flag k])
same_deps("B2 lambda-block initializer reads the OUTER k (its statements used to be skipped)",
          "  compute r : Integer = fold(xs, 0, (acc, x) -> {\n      let k = k + x\n      acc + k\n    })",
          "  compute r : Integer = fold(xs, 0, (acc, x) -> acc + (k + x))", "r", %w[k xs])
same_deps("B3 a same-spelled local that never reads the outer k is NOT a dependency",
          "  compute r : Integer = fold(xs, 0, (acc, x) -> {\n      let k = x * 3\n      acc + k\n    })",
          "  compute r : Integer = fold(xs, 0, (acc, x) -> acc + (x * 3))", "r", %w[xs])
same_deps("B4 ... and an outer read AFTER the callback is one",
          "  compute r : Integer = fold(xs, 0, (acc, x) -> {\n      let k = x * 3\n      acc + k\n    }) + k",
          "  compute r : Integer = fold(xs, 0, (acc, x) -> acc + (x * 3)) + k", "r", %w[k xs])
same_deps("B5 the ELSE branch reads the OUTER k while THEN binds a local k",
          "  compute r : Integer = if flag { let k = 100\n      k + 1 } else { k }",
          "  compute r : Integer = if flag { 101 } else { k }", "r", %w[flag k])

# C. leaks and order, with no false report for a lawfully bound local
{ "C1 use before let (e is bound, d is not yet)" =>
    ["  compute r : Collection[Integer] = map(xs, x -> {\n      let e = d + x\n      let d = 2\n      e + d\n    })", %w[d]],
  "C2 a fresh let may not read itself" =>
    ["  compute r : Integer = if flag { let d = d + 1\n      d } else { 0 }", %w[d]],
  "C3 a then-local is not in force in else" =>
    ["  compute r : Integer = if flag { let d = 1\n      d } else { d }", %w[d]],
  "C4 an inner branch local does not reach the enclosing block (q is bound)" =>
    ["  compute r : Collection[Integer] = map(xs, x -> {\n      let q = if x > 0 { let t = 1\n        t } else { 0 }\n      q + t\n    })", %w[t]],
  "C5 a missing name in an initializer is THE report (d is bound)" =>
    ["  compute r : Integer = fold(xs, 0, (acc, x) -> {\n      let d = x + missing\n      acc + d\n    })", %w[missing]],
  "C6 a callback local and a lambda parameter do not reach a later declaration" =>
    ["  compute t : Integer = fold(xs, 0, (acc, x) -> {\n      let d = x\n      acc + d\n    })\n  compute r : Integer = d + x", %w[d x]],
  "C7 a missing name inside an array literal is visited" =>
    ["  compute r : Collection[Integer] = [a, missing]", %w[missing]] }.each do |name, (decl, want)|
  c = classify(o(decl, "r"))
  check(name, unresolved(c) == want, unresolved(c).inspect)
end

# D. match arms, pattern binders, records, variants, lists
SHAPE = "variant Shape {\n  Circle { r : Integer }\n  Rect { w : Integer, h : Integer }\n}\n\n"
def shaped(decl)
  "module R15.M\n\n#{SHAPE}pure contract O {\n  input s : Shape\n  input a : Integer\n  compute k : Integer = a * 2\n  compute r : Integer = a + 100\n#{decl}\n  output area : Integer\n}\n"
end
c = classify(shaped("  compute area : Integer = match s {\n    Circle { r } => r * r * k\n    Rect { w, h } => w * h + a\n  }"))
check("D1 a match visits its subject and BOTH arm bodies; pattern binders are not deps", unresolved(c).empty? && deps(c, "area") == %w[a k s], deps(c, "area").inspect)
c = classify(shaped("  compute area : Integer = match s {\n    Circle { r } => r * r\n    Rect { w, h } => w * h + r\n  }"))
check("D2 the binder r shadows the outer r in ITS arm only; the sibling arm reads the OUTER r", deps(c, "area") == %w[r s], deps(c, "area").inspect)
c = classify(shaped("  compute area : Integer = match s {\n    Circle { r } => r * r\n    Rect { w, h } => w * h\n  }"))
check("D3 a pattern binder alone is not an outer dependency", deps(c, "area") == %w[s], deps(c, "area").inspect)
c = classify("module R15.M\n\n#{SHAPE}pure contract O {\n  input s : Shape\n  compute area : Integer = match s {\n    Circle { r } => r\n    Rect { w, h } => r * missing\n  }\n  output area : Integer\n}\n")
check("D4 a binder does not reach a sibling arm; a missing name in an arm is reported", unresolved(c) == %w[missing r], unresolved(c).inspect)
RECS = "module R15.R\n\ntype Cell { id : Integer width : Integer }\nvariant Tag {\n  On { n : Integer }\n  Off {}\n}\n\npure contract O {\n  input items : Collection[Integer]\n  input scale : Integer\n  input off : Integer\n  compute cells : Collection[Cell] = map(items, it -> {\n      let width = it * scale\n      let cell = { id: it, width: width }\n      cell\n    })\n  compute pairs : Collection[Collection[Integer]] = map(items, it -> {\n      let d = it * 2\n      let pair = [d, d + off]\n      pair\n    })\n  compute tags : Collection[Tag] = map(items, it -> {\n      let n = it + off\n      On { n: n }\n    })\n  compute plain : Collection[Integer] = [scale, off]\n  output cells : Collection[Cell]\n}\n"
c = classify(RECS)
check("D5 record fields read fresh locals and an outer input", unresolved(c).empty? && deps(c, "cells") == %w[items scale], deps(c, "cells").inspect)
check("D6 array items read a fresh local and an outer input", deps(c, "pairs") == %w[items off], deps(c, "pairs").inspect)
check("D7 variant fields read a fresh local and an outer input", deps(c, "tags") == %w[items off], deps(c, "tags").inspect)
check("D8 a plain contract-level array literal has its items as dependencies (was [])", deps(c, "plain") == %w[off scale], deps(c, "plain").inspect)

# E. UI construction
UI = File.read(HERE.join("fixtures/ui_control_list_and_card_layout.ig"))
c = classify(UI)
check("E1 UI: the map-built control list binds its fresh label/chosen", unresolved(c, "View").empty? && deps(c, "choices", "View") == %w[records selected], deps(c, "choices", "View").inspect)
check("E2 UI: the fold-built card layout reads gap/seed/selected through its fresh locals", deps(c, "laid", "View") == %w[gap records seed selected], deps(c, "laid", "View").inspect)
status, rules, sir = compile(UI)
laid = sir && sir.fetch("contracts").find { |k| k["contract_name"] == "View" }.fetch("nodes").find { |n| n["name"] == "laid" }
text = JSON.generate(laid)
check("E3 UI: the program compiles and every authored local is carried as a let, none unlowered",
      status == "ok" && %w[y color title row].all? { |l| text.include?("\"kind\":\"let\",\"name\":\"#{l}\"") || text.include?("\"name\":\"#{l}\"") } && !text.include?("\"stmts\""),
      "#{status} #{rules.inspect}")

# F. laws that must not move
status, rules, = compile(o("  compute r : Integer = fold(xs, 0, (acc, x) -> {\n      let __seq__ = x\n      acc + __seq__\n    })", "r"))
check("F1 the reserved __seq__ let is refused OOF-COL4", status != "ok" && rules.include?("OOF-COL4"), "#{status} #{rules.inspect}")
STREAM = "module R15.S\n\nobserved contract S {\n  input device_id: String\n  stream readings: Float\n\n  window \"r15/{device_id}\" {\n    kind: :count,\n    size: 3,\n    on_close: :snapshot\n  }\n\n  compute total: Float =\n    fold_stream(readings, 0.0, (acc, r) -> {\n      let d = r * 2.0\n      let e = d + 1.0\n      acc + e\n    }) @window_bounded\n  DIRECT\n  output total: Float\n}\n"
c = classify(STREAM.sub("  DIRECT\n", ""))
check("F2 fold_stream callable locals are not stream dependencies", deps(c, "total", "S") == %w[readings], deps(c, "total", "S").inspect)
c = classify(STREAM.sub("  DIRECT\n", "  compute leak : Collection[Float] = [readings]\n"))
s4 = contract(c, "S").fetch("oof_log").map { |d| d.fetch("rule") }
check("F3 a direct stream read inside an ARRAY literal is refused OOF-S4 (array children were skipped)", s4.include?("OOF-S4"), s4.inspect)
MODE = "variant Mode {\n  Raw { n : Integer }\n  Off {}\n}\n\n"
ARM = STREAM.sub("module R15.S\n\n", "module R15.S\n\n#{MODE}").sub("  stream readings: Float\n", "  input mode : Mode\n  stream readings: Float\n")
c = classify(ARM.sub("  DIRECT\n", "  compute leak : Float = match mode {\n    Raw { n } => readings\n    Off {} => 0.0\n  }\n"))
s4 = contract(c, "S").fetch("oof_log").map { |d| d.fetch("rule") }
check("F4 a direct stream read inside a MATCH ARM is refused OOF-S4 (arms were skipped: it compiled)", s4.include?("OOF-S4"), s4.inspect)
c = classify(ARM.sub("  DIRECT\n", "  compute leak : Float = if device_id == \"x\" { let readings = 1.0\n      readings } else { 0.0 }\n"))
s4 = contract(c, "S").fetch("oof_log").map { |d| d.fetch("rule") }
check("F5 a local that merely SPELLS the stream's name is not a direct stream use", !s4.include?("OOF-S4"), s4.inspect)

# G. A node's identity is its `kind`, never the keys it carries (independent review F1): a record / variant `fields`
#    map is keyed by USER field names. A first candidate shape-sniffed kind-less Hashes, so a field spelled `stmts`
#    crashed the compiler, `return_expr` erased its sibling's dependency and hid a direct stream read from OOF-S4.
KEYS = "module R15.K\n\ntype Node { stmts : Integer return_expr : Integer kind : Integer type_annotation : Integer }\nvariant V {\n  A { return_expr : Integer, stmts : Integer }\n}\n\npure contract O {\n  input a : Integer\n  input b : Integer\n  input c : Integer\n  input d : Integer\n  compute n : Node = { stmts: a, return_expr: b, kind: c, type_annotation: d }\n  compute v : V = A { return_expr: a, stmts: b }\n  compute r : Integer = n.stmts + n.return_expr\n  output r : Integer\n}\n"
c = classify(KEYS)
check("G1 record fields spelled stmts/return_expr/kind/type_annotation are ordinary fields", unresolved(c).empty? && deps(c, "n") == %w[a b c d], deps(c, "n").inspect)
check("G2 variant fields spelled return_expr/stmts are ordinary fields", deps(c, "v") == %w[a b], deps(c, "v").inspect)
status, rules, = compile(KEYS)
check("G3 ... and the program compiles (a field spelled `stmts` crashed the first candidate)", status == "ok", "#{status} #{rules.inspect}")
LEAKY = STREAM.sub("module R15.S\n\n", "module R15.S\n\ntype Leaky { return_expr : Float other : Float }\n\n")
c = classify(LEAKY.sub("  DIRECT\n", "  compute leak : Leaky = { return_expr: 1.0, other: readings }\n"))
s4 = contract(c, "S").fetch("oof_log").map { |d| d.fetch("rule") }
check("G4 a direct stream read beside a field spelled return_expr is refused OOF-S4 (the first candidate ADMITTED it)", s4.include?("OOF-S4"), s4.inspect)

puts "\n#{$pass} PASS / #{$fail} FAIL"
exit($fail.zero? ? 0 : 1)
