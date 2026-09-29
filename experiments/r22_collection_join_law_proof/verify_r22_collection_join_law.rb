#!/usr/bin/env ruby
# frozen_string_literal: true

# LANG-COLLECTION-EVIDENCE-JOIN-IMPLEMENTATION-R22 — Canon permanent conformance proof (ch3 §3.3b).
#
# The ratified collection / alternative join law executed by the Canon Ruby typechecker:
#   A. four carriers, one representation, erased at the typechecker boundary (no `carrier` key anywhere in
#      the typed program or SemanticIR; holes / openness / unnamed records spelled Unknown) and no SIR on
#      refusal;
#   B. the ONE whole-set join J: order / permutation independence of literals, if and match; a declared-open
#      member never hides a known conflict; String ≡ Text; nested conflicts; no degraded bare family;
#   C. grouping loss happens ONLY through declared openness (not universal associativity);
#   D. record naming before the join: named vs unnamed families, nested hints, Map / open context
#      suppression, ambiguity, failing hints never retried;
#   E. maps: key JOIN (relaxed map_put, checked map_get), value join, map_empty() seed, record-as-map;
#   F. unwrap_or / or_else joins;
#   G. fold fill-only refinement: multi-pass settle, late-hole cost, re-nesting, unused bad statement (exactly
#      one diagnostic, no manufactured OOF-COL4), fold_stream unchanged (ch6 §6.4.1);
#   H. errors are silent afterwards (literal members, HOF carriers, boundaries, erroneous expected types);
#   I. family-before-deferral boundaries and annotated-context fit (compute, output, def parameter);
#   J. preserved controls (optional-field construction under the P3 gate, Decimal §3.6, equality, the
#      transitional field-read and cross-scale Decimal behaviors);
#   K. the J / fit / fills_only helpers themselves (commutativity over every permutation, no invented
#      openness, family-before-deferral, fill-only).
# Every expected rule set is a hand-derived literal from §3.3b; nothing here reads a model's output.
# It writes nothing into the tree (full compiles go to a Dir.mktmpdir outside the repository).
#   ruby experiments/r22_collection_join_law_proof/verify_r22_collection_join_law.rb

require "json"
require "pathname"
require "tmpdir"

HERE = Pathname.new(__FILE__).expand_path.dirname
# R22_CANON_ROOT lets the same proof be pointed at another Canon tree (e.g. the unmodified baseline, to show
# which checks the pre-R22 typechecker fails); by default it proves the tree it lives in.
ROOT = (ENV["R22_CANON_ROOT"] ? Pathname.new(ENV["R22_CANON_ROOT"]) : HERE.join("../..")).expand_path
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

HEADER_INPUTS = <<~IG
  input seed : Integer
  input xs : Collection[Integer]
  input fs : Collection[Float]
  input cfg : Map[String, Unknown]
  input opens : Collection[Unknown]
  input om : Map[Unknown, Integer]
  input sm : Map[String, Integer]
  input tk : Text
IG

# A module with the shared inputs; `decls` are module-level declarations, `body` the contract body lines.
def program(body, decls: "")
  <<~IG
    module R22.Proof
    #{decls}
    variant M {
      Raw { n : Integer }
      Off {}
    }
    pure contract O {
    #{HEADER_INPUTS.lines.map { |l| "  #{l}" }.join}
    #{body.lines.map { |l| "  #{l}" }.join}
    }
  IG
end

def typecheck(source, optional_fields: false)
  parsed = IgniterLang::ParsedProgram.parse(source, source_path: "r22.ig").to_h
  raise "parse errors: #{parsed.fetch("parse_errors").inspect}" unless parsed.fetch("parse_errors").empty?

  IgniterLang::DerivedConstructorSugar.lower!(parsed)
  IgniterLang::ContractCallSugar.lower!(parsed)
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  IgniterLang::TypeChecker.new(optional_fields: optional_fields).typecheck(classified)
rescue StandardError => e
  { "contracts" => [], "type_errors" => [{ "rule" => "CRASH", "message" => "#{e.class}: #{e.message}" }] }
end

def errors(result)
  result.fetch("type_errors", [])
end

def rules(result)
  errors(result).map { |e| e.fetch("rule") }.uniq.sort
end

def rule_list(result)
  errors(result).map { |e| e.fetch("rule") }
end

def messages(result)
  errors(result).map { |e| "#{e["rule"]}: #{e["message"]}" }
end

def decl(result, name, contract: "O")
  c = result.fetch("contracts", []).find { |x| x["name"] == contract }
  c && c.fetch("declarations").find { |d| d["name"] == name }
end

def type_str(t)
  return t.to_s unless t.is_a?(Hash)

  params = t.fetch("params", [])
  return t.fetch("name") if params.empty?

  "#{t.fetch("name")}[#{params.map { |p| type_str(p) }.join(",")}]"
end

def decl_type(result, name, contract: "O")
  d = decl(result, name, contract: contract)
  d ? type_str(d["type"]) : "<missing>"
end

def carrier_free_tree?(node)
  case node
  when Hash then !node.key?("carrier") && node.values.all? { |v| carrier_free_tree?(v) }
  when Array then node.all? { |v| carrier_free_tree?(v) }
  else true
  end
end

# Expect exactly `expected_rules` (sorted, unique) AND no rule twice (the error is silent afterwards).
def expect_rules(name, source, expected_rules, optional_fields: false)
  r = typecheck(source, optional_fields: optional_fields)
  ok = rules(r) == expected_rules.sort && rule_list(r).length == expected_rules.length
  check(name, ok, messages(r).inspect)
  r
end

def expect_clean(name, source, optional_fields: false)
  expect_rules(name, source, [], optional_fields: optional_fields)
end

def full_compile(source)
  Dir.mktmpdir("r22-proof") do |dir|
    src = File.join(dir, "r22.ig")
    File.write(src, source)
    out = File.join(dir, "out.igapp")
    result = IgniterLang::CompilerOrchestrator.new.compile_sources(source_paths: [src], out_path: out)
    sir_file = Dir.glob(File.join(out, "**", "semantic_ir_program.json")).first
    { "status" => result["status"], "semantic_ir" => result["semantic_ir"],
      "sir_file" => sir_file && File.read(sir_file), "result" => result }
  end
end

INTERP = IgniterLang::TypeChecker.new
INTERP.instance_variable_set(:@type_shapes, { "P" => { "x" => { "name" => "Integer", "params" => [] } } })

def tc(method, *args)
  INTERP.send(method, *args)
rescue StandardError => e
  "CRASH #{e.class}"
end

def t(name, *params)
  { "name" => name, "params" => params }
end

HOLE = { "name" => "Unknown", "params" => [], "carrier" => "hole" }.freeze
OPEN = { "name" => "Unknown", "params" => [] }.freeze
ERR  = { "name" => "Unknown", "params" => [], "carrier" => "error" }.freeze

def rec(fields)
  { "name" => "Unknown", "params" => [], "carrier" => "record", "fields" => fields }
end

INT = t("Integer")
STR = t("String")
TXT = t("Text")

puts "── A: carriers, erasure, no SIR on refusal ─────────────────────────────"

ra = expect_clean("A-01 holes, unnamed records and map_empty seeds type clean", program(<<~B))
  compute e = []
  compute r = { zz: 1, q: [] }
  compute m = map_empty()
  compute c = if seed > 0 { [] } else { [1] }
  compute o : Integer = count(c)
  output o : Integer
B
check("A-02 typed program carries no inference-only carrier key", carrier_free_tree?(ra), "")
check("A-03 a hole spells Collection[Unknown] (legacy spelling)", decl_type(ra, "e") == "Collection[Unknown]", decl_type(ra, "e"))
check("A-04 an unnamed record family spells Unknown", decl_type(ra, "r") == "Unknown", decl_type(ra, "r"))
check("A-05 map_empty() spells Map[String,Unknown]", decl_type(ra, "m") == "Map[String,Unknown]", decl_type(ra, "m"))
check("A-06 if { [] } else { [1] } is Collection[Integer]", decl_type(ra, "c") == "Collection[Integer]", decl_type(ra, "c"))
check("A-07 unnamed record node spelled {name: Unknown, params: []} exactly",
      decl(ra, "r")["type"] == { "name" => "Unknown", "params" => [] }, decl(ra, "r")["type"].inspect)

ca = full_compile(program(<<~B))
  compute e = []
  compute r = { zz: 1, q: [] }
  compute m = fold(xs, map_empty(), (acc, v) -> map_put(acc, "k", v))
  compute h = unwrap_or(none(), 1)
  compute o : Integer = count(append(e, 1)) + h
  output o : Integer
B
check("A-08 admitted program emits SemanticIR", ca["status"] == "ok" && ca["sir_file"], ca["status"].inspect)
check("A-09 emitted SemanticIR has no `carrier` key", ca["sir_file"] && !ca["sir_file"].include?("\"carrier\""), "")
check("A-10 emitted SemanticIR has no record-family `fields` leak in a type position",
      ca["semantic_ir"] && carrier_free_tree?(ca["semantic_ir"]), "")
cr = full_compile(program(<<~B))
  compute ys = [1, "a"]
  compute o : Integer = count(ys)
  output o : Integer
B
check("A-11 refused program emits no SemanticIR", cr["status"] != "ok" && cr["semantic_ir"].nil? && cr["sir_file"].nil?,
      cr["status"].inspect)

puts "── B: one whole-set join, order-free ───────────────────────────────────"

members = ['some(1)', 'none()', 'map_get(cfg, "a")']
members.permutation.each_with_index do |perm, i|
  r = expect_clean("B-01.#{i} [#{perm.join(", ")}] joins (open absorbs, hole fills)", program(<<~B))
    compute c = [#{perm.join(", ")}]
    compute o : Integer = count(c)
    output o : Integer
  B
  check("B-02.#{i} … typed Collection[Option[Unknown]] in every order", decl_type(r, "c") == "Collection[Option[Unknown]]", decl_type(r, "c"))
end
hidden = ['map_get(cfg, "a")', 'some(1)', 'some("x")']
texts = hidden.permutation.map do |perm|
  r = typecheck(program(<<~B))
    compute c = [#{perm.join(", ")}]
    compute o : Integer = count(c)
    output o : Integer
  B
  check("B-03 hidden conflict [#{perm.join(", ")}] is exactly OOF-COL13", rule_list(r) == ["OOF-COL13"], messages(r).inspect)
  messages(r)
end
check("B-04 the OOF-COL13 text is order-free (sorted member list)", texts.uniq.length == 1, texts.uniq.inspect)
check("B-05 OOF-COL13 text names the known members",
      texts.first == ["OOF-COL13: collection literal members have no common family: Option[Integer], Option[String], Option[Unknown]"],
      texts.first.inspect)
expect_rules("B-06 nested conflict in an if is OOF-IF3 (no then-arm rule)", program(<<~B), ["OOF-IF3"])
  compute c = if seed > 0 { [1] } else { ["a"] }
  compute o : Integer = seed
  output o : Integer
B
expect_rules("B-07 nested conflict in an if, swapped", program(<<~B), ["OOF-IF3"])
  compute c = if seed > 0 { ["a"] } else { [1] }
  compute o : Integer = seed
  output o : Integer
B
rb8 = expect_clean("B-08 String and Text arms join (one scalar family)", program(<<~B))
  compute m = Raw { n: seed }
  compute c = match m {
    Raw { n } => int_to_text(n)
    Off {} => "off"
  }
  compute o : Integer = seed
  output o : Integer
B
check("B-09 … mixed String/Text spellings join as Text", decl_type(rb8, "c") == "Text", decl_type(rb8, "c"))
arms = ["Raw { n } => [n]", "Off {} => []"]
arms.permutation.each_with_index do |perm, i|
  r = expect_clean("B-10.#{i} match arms with a hole in either order", program(<<~B))
    compute m = Raw { n: seed }
    compute c = match m {
      #{perm.join("\n    ")}
    }
    compute o : Integer = count(c)
    output o : Integer
  B
  check("B-11.#{i} … never degraded to a bare family: Collection[Integer]", decl_type(r, "c") == "Collection[Integer]", decl_type(r, "c"))
end
expect_rules("B-12 nested arm conflict is OOF-KIND5 (not a degraded bare family)", program(<<~B), ["OOF-KIND5"])
  compute m = Raw { n: seed }
  compute c = match m {
    Raw { n } => [n]
    Off {} => ["off"]
  }
  compute o : Integer = seed
  output o : Integer
B
rb13 = expect_clean("B-13 all-hole arms keep their constructor", program(<<~B))
  compute m = Raw { n: seed }
  compute c = match m {
    Raw { n } => []
    Off {} => []
  }
  compute o : Integer = count(c)
  output o : Integer
B
check("B-14 … Collection[Unknown], not bare Collection", decl_type(rb13, "c") == "Collection[Unknown]", decl_type(rb13, "c"))
expect_rules("B-15 a hole inside never defers the known outer family (Option vs Collection)", program(<<~B), ["OOF-TY0"])
  compute c : Option[Integer] = []
  compute o : Integer = seed
  output o : Integer
B

puts "── C: grouping loss only through declared openness ─────────────────────"

expect_rules("C-01 flat set [[1], opens, [\"a\"]] has no join", program(<<~B), ["OOF-COL13"])
  compute c = [[1], opens, ["a"]]
  compute o : Integer = count(c)
  output o : Integer
B
rc2 = expect_clean("C-02 grouping through declared openness keeps only openness", program(<<~B))
  compute a = if seed > 0 { [1] } else { opens }
  compute c = [a, ["a"]]
  compute o : Integer = count(c)
  output o : Integer
B
check("C-03 … typed Collection[Collection[Unknown]]", decl_type(rc2, "c") == "Collection[Collection[Unknown]]", decl_type(rc2, "c"))
expect_rules("C-04 grouping WITHOUT declared openness remembers the family (no universal associativity loss)", program(<<~B), ["OOF-COL13"])
  compute a = if seed > 0 { [1] } else { [2] }
  compute c = [a, ["a"]]
  compute o : Integer = count(c)
  output o : Integer
B
expect_rules("C-05 context never reaches an earlier binding", program(<<~B), ["OOF-COL13"])
  compute t = [1, "a"]
  compute ys : Collection[Unknown] = t
  compute o : Integer = count(ys)
  output o : Integer
B
expect_clean("C-06 declared-open element context types a heterogeneous literal Collection[Unknown]", program(<<~B))
  compute ys : Collection[Unknown] = [1, "a"]
  compute o : Integer = count(ys)
  output o : Integer
B
expect_clean("C-07 the context reaches a nested literal member", program(<<~B))
  compute ys : Collection[Collection[Unknown]] = [[1, "a"], [true]]
  compute o : Integer = count(ys)
  output o : Integer
B
expect_rules("C-08 a slot open only as a whole does not make a nested literal opaque", program(<<~B), ["OOF-COL13"])
  compute ys : Collection[Collection[Integer]] = [[1, "a"]]
  compute o : Integer = count(ys)
  output o : Integer
B

puts "── D: record naming before the join ────────────────────────────────────"

decl_p = "type P { x : Integer }\ntype Q { x : Integer }\ntype Outer { inner : P }\ntype Alpha { alpha : Integer }"
rd1 = expect_clean("D-01 a unique fitting shape names every member", program(<<~B, decls: "type P { x : Integer }"))
  compute ps = [{ x: 1 }, { x: 2 }]
  compute o : Integer = count(ps)
  output o : Integer
B
check("D-02 … typed Collection[P]", decl_type(rd1, "ps") == "Collection[P]", decl_type(rd1, "ps"))
rd3 = expect_clean("D-03 unnamed record families join field-wise (holes fill)", program(<<~B))
  compute r = if seed > 0 { { q: [] } } else { { q: [1] } }
  compute o : Integer = seed
  output o : Integer
B
check("D-04 … the unnamed family is spelled Unknown", decl_type(rd3, "r") == "Unknown", decl_type(rd3, "r"))
expect_rules("D-05 unnamed families with different field sets have no join", program(<<~B), ["OOF-IF3"])
  compute r = if seed > 0 { { a: 1 } } else { { b: 1 } }
  compute o : Integer = seed
  output o : Integer
B
expect_rules("D-06 a named record never joins an unnamed family", program(<<~B, decls: "type P { x : Integer }"), ["OOF-IF3"])
  compute p : P = { x: 1 }
  compute r = if seed > 0 { p } else { { y: 1 } }
  compute o : Integer = seed
  output o : Integer
B
rd7 = expect_clean("D-07 a hint reaches a literal in a field of the hinted shape", program(<<~B, decls: decl_p))
  compute ob : Outer = { inner: { x: 1 } }
  compute o : Integer = ob.inner.x
  output o : Integer
B
check("D-08 … nested literal typed P", type_str(decl(rd7, "ob").dig("expr", "fields", "inner", "resolved_type")) == "P",
      decl(rd7, "ob").dig("expr", "fields", "inner", "resolved_type").inspect)
expect_rules("D-09 without the hint the inner literal is ambiguous — exactly one diagnostic", program(<<~B, decls: decl_p), ["OOF-TY0"])
  compute ob = { inner: { x: 1 } }
  compute o : Integer = seed
  output o : Integer
B
rd10 = typecheck(program(<<~B, decls: "type Q { x : Integer }\ntype P { x : Integer }"))
  compute b = [{ x: 1 }]
  compute o : Integer = seed
  output o : Integer
B
check("D-10 ambiguity lists the shapes sorted", messages(rd10) == ["OOF-TY0: Ambiguous record literal type: fields {x} match P, Q"], messages(rd10).inspect)
rd11 = expect_clean("D-11 a Map expected type suppresses structural naming", program(<<~B, decls: decl_p))
  compute m : Map[String, Integer] = { alpha: 1 }
  compute o : Integer = unwrap_or(map_get(m, "alpha"), 0)
  output o : Integer
B
check("D-12 … the binding is the Map", decl_type(rd11, "m") == "Map[String,Integer]", decl_type(rd11, "m"))
expect_rules("D-13 a record literal meets a Map slot only by fit (field misfit refused at the boundary)", program(<<~B, decls: decl_p), ["OOF-TY0"])
  compute m : Map[String, String] = { alpha: 1 }
  compute o : Integer = seed
  output o : Integer
B
expect_rules("D-14 a failing hint is refused and never retried with another shape", program(<<~B, decls: "type IntBox { x : Integer }\ntype StrBox { x : String }"), ["OOF-TY0"])
  compute a : IntBox = { x: "a" }
  compute o : Integer = seed
  output o : Integer
B
expect_rules("D-15 a stdlib map argument is not a Map context (declared naming cost)", program(<<~B, decls: "type A { a : Integer }"), ["OOF-TY0"])
  compute v = map_get({ a: 1 }, "a")
  compute o : Integer = seed
  output o : Integer
B
expect_clean("D-16 a declared-open element context suppresses naming of its members", program(<<~B, decls: decl_p))
  compute ys : Collection[Unknown] = [{ alpha: 1 }, { beta: "b" }]
  compute o : Integer = count(ys)
  output o : Integer
B
rd17 = typecheck(program(<<~B, decls: decl_p))
  compute ob = { inner: { y: 1 } }
  compute o2 : Outer = ob
  compute o : Integer = seed
  output o : Integer
B
check("D-17 an unnamed inner literal is judged by its record family, never as open (no shape names the outer)",
      messages(rd17) == ["OOF-TY0: Binding type mismatch: declared Outer, got Unknown"], messages(rd17).inspect)

puts "── E: maps and keys ────────────────────────────────────────────────────"

re1 = expect_clean("E-01 map_put key JOINS a declared-open key family (Integer into Map[Unknown, V])", program(<<~B))
  compute m2 = map_put(om, 1, 2)
  compute o : Integer = seed
  output o : Integer
B
check("E-02 … result keeps only openness in the key: Map[Unknown,Integer]", decl_type(re1, "m2") == "Map[Unknown,Integer]", decl_type(re1, "m2"))
re3 = typecheck(program(<<~B))
  compute m2 = map_put(sm, 1, 2)
  compute o : Integer = seed
  output o : Integer
B
check("E-03 map_put key with no join keeps its owner text",
      messages(re3) == ["OOF-TY0: stdlib.map.put arg 2: expected String key, got Integer"], messages(re3).inspect)
re4 = typecheck(program(<<~B))
  compute v = map_get(sm, 1)
  compute o : Integer = seed
  output o : Integer
B
check("E-04 map_get key is now checked by the join", messages(re4) == ["OOF-TY0: stdlib.map.get arg 2: expected String key, got Integer"], messages(re4).inspect)
expect_clean("E-05 String ≡ Text in the key join", program(<<~B))
  compute v = unwrap_or(map_get(sm, tk), 0)
  compute m2 = map_put(sm, tk, 3)
  compute o : Integer = v
  output o : Integer
B
re6 = expect_clean("E-06 map_put fills the map_empty() value hole", program(<<~B))
  compute m = map_put(map_empty(), "k", 1)
  compute o : Integer = unwrap_or(map_get(m, "k"), 0)
  output o : Integer
B
check("E-07 … Map[String,Integer]", decl_type(re6, "m") == "Map[String,Integer]", decl_type(re6, "m"))
re8 = expect_clean("E-08 a record literal used as a map offers key String and the join of its fields", program(<<~B))
  compute v = map_get({ a: 1, b: 2 }, "a")
  compute o : Integer = unwrap_or(v, 0)
  output o : Integer
B
check("E-09 … Option[Integer]", decl_type(re8, "v") == "Option[Integer]", decl_type(re8, "v"))
re10 = typecheck(program(<<~B))
  compute v = map_put({ a: 1, b: "x" }, "c", 2)
  compute o : Integer = seed
  output o : Integer
B
check("E-10 record-as-map fields with no join (map_put owner text)",
      messages(re10) == ["OOF-TY0: map_put: record fields have no common value family: Integer, String"], messages(re10).inspect)
expect_rules("E-11 record-as-map value join refuses a foreign value", program(<<~B), ["OOF-TY0"])
  compute v = map_put({ a: 1 }, "b", "x")
  compute o : Integer = seed
  output o : Integer
B
expect_rules("E-12 a record-literal seed never joins a Map body", program(<<~B), ["OOF-COL4"])
  compute m = fold(xs, {}, (acc, v) -> map_put(acc, "k", v))
  compute o : Integer = seed
  output o : Integer
B
expect_rules("E-13 a written Integer map key stays OOF-MAP1 (and its boundary is silent)", program(<<~B), ["OOF-MAP1"])
  compute m : Map[Integer, Integer] = map_empty()
  compute o : Integer = seed
  output o : Integer
B

puts "── F: unwrap_or / or_else ──────────────────────────────────────────────"

rf1 = typecheck(program(<<~B))
  compute v = unwrap_or(some(1), "a")
  compute w = or_else(some(1), "a")
  compute o : Integer = seed
  output o : Integer
B
check("F-01 unwrap_or / or_else with no join (DESIGN §6 texts)",
      messages(rf1) == ["OOF-TY0: unwrap_or: payload Integer and fallback String have no common family",
                        "OOF-TY0: or_else: payload Integer and fallback String have no common family"], messages(rf1).inspect)
rf2 = expect_clean("F-02 a hole payload takes the fallback family", program(<<~B))
  compute v = unwrap_or(none(), 1)
  compute w = or_else(none(), "z")
  compute o : Integer = v
  output o : Integer
B
check("F-03 … Integer / String", decl_type(rf2, "v") == "Integer" && decl_type(rf2, "w") == "String",
      "#{decl_type(rf2, "v")} #{decl_type(rf2, "w")}")
rf4 = expect_clean("F-04 a declared-open payload keeps openness", program(<<~B))
  compute v = unwrap_or(map_get(cfg, "q"), [])
  compute c = concat(v, [1])
  compute o : Integer = count(c)
  output o : Integer
B
check("F-05 … v Unknown, c Collection[Unknown]", decl_type(rf4, "v") == "Unknown" && decl_type(rf4, "c") == "Collection[Unknown]",
      "#{decl_type(rf4, "v")} #{decl_type(rf4, "c")}")

puts "── G: fold fill-only refinement ────────────────────────────────────────"

rg1 = expect_clean("G-01 fold settles at J(seed, body)", program(<<~B))
  compute c = fold(xs, [], (acc, v) -> append(acc, v))
  compute o : Integer = count(c)
  output o : Integer
B
check("G-02 … accumulator Collection[Integer] (never typed from one item)", decl_type(rg1, "c") == "Collection[Integer]", decl_type(rg1, "c"))
check("G-03 … the kept lowering body is the settled pass's", type_str(decl(rg1, "c").dig("expr", "args", 2, "body", "resolved_type")) == "Collection[Integer]",
      decl(rg1, "c").dig("expr", "args", 2, "body", "resolved_type").inspect)
expect_clean("G-04 multi-pass fill-only refinement settles", program(<<~B))
  compute r = fold(xs, { a: [], b: [] }, (acc, v) -> { a: [v], b: unwrap_or(map_get(acc, "a"), []) })
  compute o : Integer = seed
  output o : Integer
B
rg5 = typecheck(program(<<~B))
  compute r = fold(xs, { a: [], b: [] }, (acc, v) -> { a: [[]], b: unwrap_or(map_get(acc, "a"), []) })
  compute o : Integer = seed
  output o : Integer
B
check("G-05 a later pass gaining a new hole is OOF-COL4 (declared cost)", rule_list(rg5) == ["OOF-COL4"] &&
      messages(rg5).first.include?("accumulator gains a new hole after its first refinement"), messages(rg5).inspect)
rg6 = typecheck(program(<<~B))
  compute c = fold(xs, [], (acc, v) -> [acc])
  compute o : Integer = seed
  output o : Integer
B
check("G-06 re-nesting never settles (OOF-COL4, text)",
      messages(rg6) == ["OOF-COL4: stdlib.collection.fold: accumulator gains a new hole after its first refinement: " \
                        "Collection[Collection[Unknown]] -> Collection[Collection[Collection[Unknown]]]"], messages(rg6).inspect)
expect_rules("G-07 an unused bad statement reports once — no manufactured OOF-COL4", program(<<~B), ["OOF-TY0"])
  compute c = fold(xs, [], (acc, v) -> {
    let bad = 1 + "a"
    append(acc, v)
  })
  compute o : Integer = count(c)
  output o : Integer
B
expect_rules("G-08 … also when refinement needs two passes", program(<<~B), ["OOF-TY0"])
  compute r = fold(xs, { a: [], b: [] }, (acc, v) -> {
    let bad = 1 + "a"
    { a: [v], b: unwrap_or(map_get(acc, "a"), []) }
  })
  compute o : Integer = seed
  output o : Integer
B
expect_rules("G-09 a body element conflict keeps its owner (OOF-COL6) and no second fold diagnostic", program(<<~B), ["OOF-COL6"])
  compute c = fold(xs, [1], (acc, v) -> append(acc, "a"))
  compute o : Integer = count(c)
  output o : Integer
B
rg10 = typecheck(program(<<~B))
  compute c = fold(xs, 0, (acc, v) -> "s")
  compute o : Integer = seed
  output o : Integer
B
check("G-10 no join between seed and body keeps the existing fold owner text",
      messages(rg10) == ["OOF-COL4: stdlib.collection.fold: lambda return type String does not match accumulator type Integer"], messages(rg10).inspect)
rg11 = expect_clean("G-11 nested accumulator idiom settles", program(<<~B))
  compute c = fold(xs, [], (acc, v) -> append(acc, [v]))
  compute o : Integer = count(c)
  output o : Integer
B
check("G-12 … Collection[Collection[Integer]]", decl_type(rg11, "c") == "Collection[Collection[Integer]]", decl_type(rg11, "c"))
expect_clean("G-13 a fold inside a fold body refines independently", program(<<~B))
  compute t : Float = fold(fs, 0.0, (acc, r) -> acc + fold(filter([r, 1.0], (q) -> q > 2.0), 0.0, (a, v) -> a + v))
  compute o : Integer = seed
  output o : Integer
B
stream_src = <<~IG
  module R22.Stream

  observed contract S {
    input device_id: String
    stream readings: Integer

    window "r22/{device_id}" {
      kind: :count,
      size: 3,
      on_close: :snapshot
    }

    compute total: Collection[Integer] =
      fold_stream(readings, [], (acc, r) -> [acc]) @window_bounded

    output total: Collection[Integer]
  }
IG
rs = typecheck(stream_src)
check("G-14 fold_stream keeps its ch6 §6.4.1 rule (top-level family agreement, no §3.3b refinement)",
      !rules(rs).include?("OOF-COL4"), messages(rs).inspect)
# R22 A1 (F2) [D]: there is no fifth carrier — a seed that still carries a hole is refused at the fold_stream by its
# existing owner (the transitional accumulator is never refined, so the hole is never solved), never by a strict
# output-port marker. The verdict (refused) is unchanged; the owner moves from the port (OOF-TY1) to the origin.
check("G-14b … and its unrefined seed hole is never evidence: the fold_stream's own owner refuses the init (exactly one)",
      messages(rs) == ["OOF-TY0: fold_stream 'total' init is untypeable - the init expression must have a static type"], messages(rs).inspect)
def stream_program(ty, init, body)
  <<~IG
    module R22.Stream2
    observed contract S {
      input device_id: String
      input r0: Float
      stream readings: Float
      window "r22/{device_id}" {
        kind: :count,
        size: 3,
        on_close: :snapshot
      }
      compute total: #{ty} =
        fold_stream(readings, #{init}, (acc, r) -> #{body}) @window_bounded
      output total: #{ty}
    }
  IG
end
# mid-R22 both candidates admitted the first two (the unrefined seed hole fit the output); both baselines refused.
# R22 A1 (F2) [D]: the refusal is the fold_stream's own existing owner (see G-14b), in both compilers.
[
  ["Collection[Float]", "[]", "append(acc, \"x\")", ["OOF-TY0: fold_stream 'total' init is untypeable - the init expression must have a static type"]],
  ["Map[String, Float]", "map_empty()", "map_put(acc, \"k\", \"x\")", ["OOF-TY0: fold_stream 'total' init is untypeable - the init expression must have a static type"]],
  ["Collection[Float]", "[r0]", "append(acc, r)", []],
  ["Option[Float]", "none()", "some(r)", []]
].each_with_index do |(ty, init, body, want), i|
  r = typecheck(stream_program(ty, init, body))
  check("G-#{15 + i} fold_stream seed #{init} into #{ty}: #{want.empty? ? "admitted" : "the pre-R22 owner"}", messages(r) == want, messages(r).inspect)
end

puts "── H: errors are silent afterwards ─────────────────────────────────────"

expect_rules("H-01 an if with no join, then a boundary: one diagnostic", program(<<~B), ["OOF-IF3"])
  compute a = if seed > 0 { 1 } else { "a" }
  compute b : Integer = a
  compute c : String = a
  compute o : Integer = seed
  output o : Integer
B
expect_rules("H-02 an erroneous literal member makes no OOF-COL13", program(<<~B), ["OOF-TY0"])
  compute ys = [1 + "a", "b"]
  compute o : Integer = count(ys)
  output o : Integer
B
expect_rules("H-03 a heterogeneous HOF carrier is an error; its callback is silent", program(<<~B), ["OOF-COL13"])
  compute c = map([1, "a"], v -> v + 1)
  compute d : Collection[String] = c
  compute o : Integer = count(c)
  output o : Integer
B
expect_rules("H-04 an unresolved name inside a literal reports once", program(<<~B), ["OOF-P1"])
  compute ys = [missing_name, "b", 1]
  compute o : Integer = seed
  output o : Integer
B
expect_rules("H-05 an error flowing into append / concat / unwrap_or is silent", program(<<~B), ["OOF-IF3"])
  compute a = if seed > 0 { [1] } else { "a" }
  compute b = append(a, "x")
  compute c = concat(a, ["y"])
  compute d = unwrap_or(some(a), 3)
  compute e = map_put(sm, "k", a)
  compute o : Integer = seed
  output o : Integer
B
expect_rules("H-06 an error reaching an output boundary is silent", program(<<~B), ["OOF-COL13"])
  compute o = [1, "a"]
  output o : Collection[Integer]
B

puts "── I: boundaries and annotated context ─────────────────────────────────"

expect_clean("I-01 annotated match fits each arm to declared openness", program(<<~B))
  compute m = Raw { n: seed }
  compute c : Collection[Unknown] = match m {
    Raw { n } => [n]
    Off {} => ["off"]
  }
  compute o : Integer = count(c)
  output o : Integer
B
ri2 = typecheck(program(<<~B))
  compute c : Integer = if seed > 0 { 1 } else { "a" }
  compute o : Integer = seed
  output o : Integer
B
check("I-02 under an annotated compute, no join with a misfit keeps the if's own owner OOF-IF3, once (no boundary cascade)",
      messages(ri2) == ["OOF-IF3: if_expr branch types must match: then=Integer, else=String"], messages(ri2).inspect)
ri3 = typecheck(program(<<~B))
  compute o = if seed > 0 { 1 } else { "a" }
  output o : Integer
B
check("I-03 under an annotated output port, no join with a misfit keeps OOF-IF3, once",
      messages(ri3) == ["OOF-IF3: if_expr branch types must match: then=Integer, else=String"], messages(ri3).inspect)
expect_clean("I-04 a def parameter is the written context of its argument literal", program(<<~B, decls: "def size(ys: Collection[Unknown]) -> Integer {\n  count(ys)\n}"))
  compute n = size([1, "a"])
  compute o : Integer = n
  output o : Integer
B
expect_rules("I-05 a def argument fits family-before-deferral", program(<<~B, decls: "def size(ys: Collection[Integer]) -> Integer {\n  count(ys)\n}"), ["OOF-TY0"])
  compute n = size(some([]))
  compute o : Integer = n
  output o : Integer
B
expect_clean("I-06 a hole actual fits a concrete output port", program(<<~B))
  compute o = map([], v -> v)
  output o : Collection[Integer]
B
expect_clean("I-07 a declared-open actual fits (checked at run time)", program(<<~B))
  compute o = map_get(cfg, "k")
  output o : Option[Integer]
B
expect_rules("I-08 a nested Unknown no longer defers a variant field's outer family (OOF-KIND2)", program(<<~B, decls: "variant V {\n  Box { items : Collection[Integer] }\n}"), ["OOF-KIND2"])
  compute v = Box { items: some([]) }
  compute o : Integer = seed
  output o : Integer
B

ri9 = typecheck(<<~IG)
  module R22.Dynamic
  pure contract Double {
    input n : Integer
    compute result = n + n
    output result : Integer
  }
  pure contract Caller {
    input n : Integer
    compute callee = "Double"
    compute result = call_contract(callee, n, n)
    output result : Integer
  }
IG
# R22 A1 (F2) [D]: a dynamic callee's result justifies none of the four carriers — the diagnostic is at the call
# (its originating site), never a fifth carrier refused later by the output port.
check("I-09 a Tier-2 dynamic call_contract result is none of the four carriers: the call itself is refused, once",
      messages(ri9) == ["OOF-TY0: call_contract: callee must be a String literal (a dynamic callee has no static output type)"], messages(ri9).inspect)
ri10 = expect_clean("I-10 a nested filter_map is typed by its OWN context, not the declaration's (position-scoped)", <<~IG)
  module R22.NestedFilterMap
  import stdlib.collection.{ filter_map, map }
  pure contract NestedFilterMapTagged {
    compute rows : Collection[Collection[Integer]] = [[1, 2], [3]]
    compute kept : Collection[Collection[Integer]] = map(
      rows,
      row -> filter_map(
        row,
        x -> if x > 1 { some(x) } else { none() }
      )
    )
    output kept : Collection[Collection[Integer]]
  }
IG
check("I-11 … kept is Collection[Collection[Integer]]", decl_type(ri10, "kept", contract: "NestedFilterMapTagged") == "Collection[Collection[Integer]]",
      decl_type(ri10, "kept", contract: "NestedFilterMapTagged"))
expect_clean("I-12 an annotated def return fits each branch", program(<<~B, decls: "def pick(c: Bool) -> Collection[Unknown] {\n  if c { [1] } else { [\"a\"] }\n}"))
  compute n = count(pick(seed > 0))
  compute o : Integer = n
  output o : Integer
B
ri13 = typecheck(program(<<~B, decls: "def bad(c: Bool) -> Integer {\n  if c { 1 } else { \"a\" }\n}"))
  compute o : Integer = bad(seed > 0)
  output o : Integer
B
check("I-13 under a def return, no join with a misfit keeps OOF-IF3, once",
      messages(ri13) == ["OOF-IF3: if_expr branch types must match: then=Integer, else=String"], messages(ri13).inspect)
ri14 = typecheck(program(<<~B))
  compute c : Integer = if seed > 0 { "a" } else { "b" }
  compute o : Integer = seed
  output o : Integer
B
check("I-14 a join that misfits the annotated compute is judged once by the boundary (OOF-TY0)",
      messages(ri14) == ["OOF-TY0: Binding type mismatch: declared Integer, got String"], messages(ri14).inspect)
expect_clean("I-15 a declared-open output port is the written context of its same-named compute literal", program(<<~B))
  compute ys = [1, "a"]
  output ys : Collection[Unknown]
B
expect_clean("I-16 … its branches (no join, every branch fits)", program(<<~B))
  compute ys = if seed > 0 { [1] } else { ["a"] }
  output ys : Collection[Unknown]
B
expect_clean("I-17 … and its literal members' branches", program(<<~B))
  compute ys = [if seed > 0 { 1 } else { "a" }]
  output ys : Collection[Unknown]
B
expect_rules("I-18 the port context never reaches an earlier binding", program(<<~B), ["OOF-COL13"])
  compute t = [1, "a"]
  compute ys = t
  output ys : Collection[Unknown]
B
ri19 = typecheck(program(<<~B))
  compute m = Raw { n: seed }
  compute r = match m {
    Raw { n } => n
    Off {} => "off"
  }
  output r : String
B
check("I-19 no join over arms under a port context keeps OOF-KIND5 (the view-engine KIND5 fixture shape), once",
      messages(ri19) == ["OOF-KIND5: match on 'M' has divergent arm result types: Integer, String"], messages(ri19).inspect)
expect_rules("I-20 a port type refused by the fail-closed law installs no context (OOF-IF3 stays)", program(<<~B), ["OOF-IF3", "OOF-TY0"])
  compute r = if seed > 0 { "a" } else { 0 }
  output r : Unknown
B
FAMILY_DECLS = "type P { x : Integer }\ndef px(p: P) -> Integer {\n  p.x\n}\nvariant V {\n  Box { p : P }\n}"
ri21 = typecheck(program(<<~B, decls: FAMILY_DECLS))
  compute r = { y: seed }
  compute a = px(r)
  compute o : Integer = a
  output o : Integer
B
check("I-21 an unnamed record family is fit field-wise at a def parameter",
      messages(ri21) == ["OOF-TY0: Call to 'px': parameter 'p' expects P, got Unknown"], messages(ri21).inspect)
ri22 = typecheck(program(<<~B, decls: "type P { x : Integer }\ndef mk(n: Integer) -> P {\n  let r = { y: n }\n  r\n}"))
  compute a = mk(seed)
  compute o : Integer = seed
  output o : Integer
B
check("I-22 … at a def return",
      messages(ri22) == ["OOF-TY0: function 'mk': body type Unknown does not match declared return type P"], messages(ri22).inspect)
ri23 = typecheck(program(<<~B, decls: FAMILY_DECLS))
  compute r = { y: seed }
  compute v = Box { p: r }
  compute o : Integer = seed
  output o : Integer
B
check("I-23 … at a variant field",
      messages(ri23) == ["OOF-KIND2: V::Box field 'p': expected P, got Unknown"], messages(ri23).inspect)
expect_clean("I-24 control: a record family that fits the shape is named and admitted", program(<<~B, decls: FAMILY_DECLS))
  compute r = { x: seed }
  compute a = px(r)
  compute o : Integer = a
  output o : Integer
B
HINT_DECLS = "type P { x : Integer }\ntype Q { p : P }\nvariant V {\n  Box { p : P }\n}\n" \
             "def px(p: P) -> Integer {\n  p.x\n}\ndef mk(n: Integer) -> P {\n  { x: n }\n}\n" \
             "contract Callee {\n  input p : P\n  compute r = p.x\n  output r : Integer\n}"
[
  ["parameter", "compute a = px({ x: \"a\" })"],
  ["variant field", "compute v = Box { p: { x: \"a\" } }"],
  ["nested field", "compute q : Q = { p: { x: \"a\" } }"],
  ["element", "compute ps : Collection[P] = [{ x: \"a\" }]"],
  ["branch", "compute c : P = if seed > 0 { { x: 1 } } else { { x: \"a\" } }"],
  ["call_contract input", "compute a = call_contract(\"Callee\", { x: \"a\" })"]
].each_with_index do |(where, body), i|
  r = typecheck(program("#{body}\ncompute o : Integer = seed\noutput o : Integer", decls: HINT_DECLS))
  check("I-#{25 + i} a failing hint at a #{where} is OOF-TY0, once",
        messages(r) == ["OOF-TY0: record literal field 'x': expected Integer, got String"], messages(r).inspect)
end
ri31 = typecheck(program(<<~B, decls: "type P { x : Integer }\ndef bad(n: Integer) -> P {\n  { x: \"a\" }\n}"))
  compute a = bad(seed)
  compute o : Integer = seed
  output o : Integer
B
check("I-31 a failing def-return hint is OOF-TY0, once",
      messages(ri31) == ["OOF-TY0: record literal field 'x': expected Integer, got String"], messages(ri31).inspect)
expect_clean("I-32 a declared-open variant field is the own context of its literal", program(<<~B, decls: "variant W {\n  Bag { items : Collection[Unknown] }\n}"))
  compute v = Bag { items: [1, "a"] }
  compute o : Integer = seed
  output o : Integer
B
ri33 = typecheck(program(<<~B, decls: "type CV { kind : Text, num_val : Float?, str_val : Text? }"))
  compute c : CV = { kind: "N", num_val: some(1.0), str_val: none() }
  compute o : Integer = seed
  output o : Integer
B
check("I-33 gate OFF a `T?` shape field is `T` (P3), so an Option value misfits the hint",
      messages(ri33) == ["OOF-TY0: record literal field 'num_val': expected Float, got Option[Float]",
                         "OOF-TY0: record literal field 'str_val': expected Text, got Option[Unknown]"], messages(ri33).inspect)

puts "── J: preserved controls ───────────────────────────────────────────────"

rj1 = expect_clean("J-01 optional-field construction (gate ON) omits an optional field", program(<<~B, decls: "type Opt { a : Integer, b : Integer? }"), optional_fields: true)
  compute ob : Opt = { a: 1 }
  compute oc : Opt = { a: 1, b: 2 }
  compute o : Integer = ob.a
  output o : Integer
B
check("J-02 … present raw value auto-wrapped in Some", decl(rj1, "oc").dig("expr", "fields", "b", "kind") == "option_value_construct",
      decl(rj1, "oc").dig("expr", "fields", "b").inspect[0, 200])
expect_rules("J-03 optional-field construction (gate OFF) unchanged", program(<<~B, decls: "type Opt { a : Integer, b : Integer? }"), ["OOF-TY0"])
  compute ob : Opt = { a: 1 }
  compute o : Integer = ob.a
  output o : Integer
B
rj4 = expect_clean("J-04 Decimal * across scales is Decimal[A+B] (§3.6)", program(<<~B))
  compute d = decimal(1, 2) * decimal(1, 3)
  compute o : Integer = seed
  output o : Integer
B
check("J-05 … Decimal[5]", decl_type(rj4, "d") == "Decimal[5]", decl_type(rj4, "d"))
expect_rules("J-06 Decimal + across scales is OOF-TC5 (§3.6 owner)", program(<<~B), ["OOF-TC5"])
  compute d = decimal(1, 2) + decimal(1, 3)
  compute o : Integer = seed
  output o : Integer
B
rj7 = expect_clean("J-07 TRANSITIONAL cross-scale Decimal if keeps the first member's scale", program(<<~B))
  compute d = if seed > 0 { decimal(1, 2) } else { decimal(1, 3) }
  compute o : Integer = seed
  output o : Integer
B
check("J-08 … Decimal[2]", decl_type(rj7, "d") == "Decimal[2]", decl_type(rj7, "d"))
expect_rules("J-09 equality over collections stays refused", program(<<~B), ["OOF-TY0"])
  compute b = xs == [1]
  compute o : Integer = seed
  output o : Integer
B
expect_rules("J-10 TRANSITIONAL field read on a declared-open receiver stays OOF-P1", program(<<~B), ["OOF-P1"])
  compute v = unwrap_or(map_get(cfg, "q"), 0)
  compute w = v.x
  compute o : Integer = seed
  output o : Integer
B
expect_rules("J-11 TRANSITIONAL field read on an unnamed record family stays OOF-P1", program(<<~B), ["OOF-P1"])
  compute r = { zz: 1 }
  compute w = r.zz
  compute o : Integer = seed
  output o : Integer
B
expect_clean("J-12 a named variant is the heterogeneous carrier", program(<<~B))
  compute ys = [Raw { n: 1 }, Off {}]
  compute o : Integer = count(ys)
  output o : Integer
B

puts "── K: J / fit / fills_only helpers ─────────────────────────────────────"

sets = [
  [HOLE, INT, OPEN], [t("Collection", HOLE), t("Collection", INT), t("Collection", OPEN)],
  [t("Option", INT), t("Option", HOLE), t("Option", STR)], [STR, TXT, HOLE],
  [rec("a" => INT, "b" => t("Collection", HOLE)), rec("a" => HOLE, "b" => t("Collection", STR))],
  [t("Map", STR, HOLE), t("Map", STR, INT), t("Map", OPEN, INT)], [INT, STR, OPEN], [ERR, INT, STR]
]
sets.each_with_index do |set, i|
  results = set.permutation.map { |perm| tc(:join_types, perm) }.uniq
  check("K-01.#{i} J is permutation-independent over #{set.length}! orders", results.length == 1, results.inspect)
end
check("K-02 J never invents openness: J(hole, Integer) = Integer", tc(:join_types, [HOLE, INT]) == INT)
check("K-03 J of holes only stays a hole", tc(:join_types, [HOLE, HOLE]) == HOLE)
check("K-04 J(open, hole) is open", tc(:join_types, [OPEN, HOLE]) == OPEN)
check("K-05 an open member never hides a known conflict", tc(:join_types, [INT, OPEN, STR]).nil?)
check("K-06 an error at any depth makes the join an error", tc(:join_types, [t("Collection", ERR), INT]) == ERR)
check("K-07 String ≡ Text joins as Text", tc(:join_types, [STR, TXT]) == TXT)
check("K-08 a record family never joins a Map or a named record",
      tc(:join_types, [rec("a" => INT), t("Map", STR, INT)]).nil? && tc(:join_types, [rec("x" => INT), t("P")]).nil?)
check("K-09 fit: an inner hole never defers the outer family", tc(:fit, t("Collection", HOLE), INT) == :no)
check("K-10 fit: a hole position fits", tc(:fit, t("Collection", HOLE), t("Collection", INT)) == :yes)
check("K-11 fit: an open actual fits (runtime-checked)", tc(:fit, OPEN, t("Map", STR, INT)) == :yes)
check("K-12 fit: an error actual or expected is :error (silent)", tc(:fit, ERR, INT) == :error && tc(:fit, INT, t("Option", ERR)) == :error)
check("K-13 fit: a record family fits Map[String, V] when every field fits V",
      tc(:fit, rec("a" => INT, "b" => INT), t("Map", STR, INT)) == :yes && tc(:fit, rec("a" => INT, "b" => STR), t("Map", STR, INT)) == :no)
check("K-14 fit: a record family fits a declared shape with exactly its fields",
      tc(:fit, rec("x" => INT), t("P")) == :yes && tc(:fit, rec("x" => STR), t("P")) == :no && tc(:fit, rec("y" => INT), t("P")) == :no)
check("K-15 fills_only: a hole may be filled by a hole-free type", tc(:fills_only?, t("Collection", HOLE), t("Collection", INT)))
check("K-16 fills_only: a hole filled by a hole-bearing type is refused", !tc(:fills_only?, t("Collection", HOLE), t("Collection", t("Collection", HOLE))))
check("K-17 fills_only: a hole may become open", tc(:fills_only?, HOLE, OPEN))
check("K-18 fills_only: a known family never changes", !tc(:fills_only?, INT, STR))

puts "── R: the independent review's witnesses (REVIEW-1 F1-F12; the table is shared with the Rust tests) ──"

# fixtures/EXPECT.json is byte-identical to the Rust tests' tests/fixtures/r22_review/EXPECT.json. Every row owned by
# both compilers is compiled end to end and must give exactly its rule set (empty = admitted with carrier-free
# SemanticIR). Rows marked "rust" record a pre-existing Canon gap (no invoke-argument owner, an unparsed form, a
# non-variant match subject crash) and are listed, not run.
review = JSON.parse(File.read(HERE.join("fixtures/EXPECT.json")))
review.fetch("rows").each do |row|
  next unless row.fetch("compilers") == "both"

  source = File.read(HERE.join("fixtures", row.fetch("fixture")))
  compiled = full_compile(source)
  diags = compiled.dig("result", "compilation_report", "diagnostics") || compiled.dig("result", "diagnostics") || []
  got = diags.map { |d| d["rule"] }.compact.uniq.sort
  want = row.fetch("rules")
  sir_text = compiled["sir_file"] || JSON.generate(compiled["semantic_ir"] || {})
  leak = sir_text.include?('"carrier"') || sir_text.include?('carrier\\"')
  admitted = compiled["status"] == "ok"
  check("R #{row.fetch("finding")} #{row.fetch("fixture")}: #{want.empty? ? "admitted" : want.join(", ")}",
        got == want && admitted == want.empty? && !leak,
        "status=#{compiled["status"]} got=#{got.inspect} leak=#{leak}")
end

puts
puts "#{$pass} passed, #{$fail} failed"
exit($fail.zero? ? 0 : 1)
