#!/usr/bin/env ruby
# frozen_string_literal: true

# LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 — Canon permanent proof.
#
# On the ORDINARY route the typechecker typed a block's statements and then DROPPED them: `infer_lambda_body`
# returned the typed final expression alone, and `infer_if_expr` typed a branch's final expression in the
# OUTER scope. The emitter therefore never saw a statement, and the program silently read the outer binding
# (rv02g: 32.0 for 6.0; rv12g: 2 for 3). R14:
#   A. a lambda block and a branch WITH statements reach SIR as the one right-nested `let` chain a def body
#      already uses (`function_body_ir`), in authored order; a bare statement binds `__seq__`;
#   B. the ordinary fold body is the SAME tree as the accepted `fold_stream` carrier body of the same lambda,
#      once Canon's type annotations are erased (the carrier is untyped by law);
#   C. branch statements are typed in a block scope on EVERY route: an Integer/Float shadow selects the inner
#      binder's identity (was OOF-TY0), and an effect in a branch let is no longer admitted untyped;
#   D. `deps` stay the node's FREE names — a name read after its own `let` is local;
#   E. binder scope, wrong type, arity, effect, reserved-binder and name failures refuse;
#   F. statement-less bodies are unchanged; the fresh-named let (R14 classifier residual) is admitted since R15.
# Values are executed by the Lab packet proofs/lang-ordinary-hof-lexical-block-lowering-implementation-r14.

require "json"
require "pathname"
require "tmpdir"

HERE = Pathname.new(__FILE__).expand_path.dirname
ROOT = HERE.join("../..").expand_path
LIB = ROOT.join("lib").to_s
$LOAD_PATH.unshift(LIB) unless $LOAD_PATH.include?(LIB)
require "igniter_lang"

FIXTURES = HERE.join("fixtures")
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

def compile(fixture)
  Dir.mktmpdir("r14canon") do |dir|
    out = File.join(dir, "out.igapp")
    result = IgniterLang::CompilerOrchestrator.new.compile_sources(source_paths: [FIXTURES.join(fixture).to_s], out_path: out)
    diags = result.dig("compilation_report", "diagnostics") || result["diagnostics"] || []
    sir_path = File.join(out, "semantic_ir_program.json")
    sir = File.exist?(sir_path) ? JSON.parse(File.read(sir_path)) : nil
    [result["status"], diags.map { |d| d["rule"] }.uniq.sort, sir]
  end
end

def node(sir, contract, name)
  sir.fetch("contracts").find { |c| c["contract_name"] == contract }.fetch("nodes").find { |n| n["name"] == name && n.key?("expr") }
end

# pre-order let names (a let: name, its expression, its body), ordering identities, unlowered blocks
def facts(expr, acc = { lets: [], ids: [], unlowered: 0 })
  case expr
  when Hash
    kind = expr["kind"]
    acc[:unlowered] += 1 if kind == "block" || (kind.nil? && (expr.key?("stmts") || expr.key?("return_expr")))
    if kind == "let"
      acc[:lets] << expr["name"]
      facts(expr["expr"], acc)
      facts(expr["body"], acc)
    elsif kind == "if_expr"
      %w[condition then_branch else_branch].each { |k| facts(expr[k], acc) }
    else
      acc[:ids] << expr["fn"] if kind == "call" && expr["fn"].to_s.match?(/\Astdlib\.(integer|float|decimal)\.(lt|lte|gt|gte)\z/)
      expr.each { |k, v| facts(v, acc) unless k == "resolved_type" }
    end
  when Array
    expr.each { |v| facts(v, acc) }
  end
  acc
end

# The stream carrier is untyped by law; erase Canon's annotations (and its literal spelling) to compare trees.
def erased(expr)
  case expr
  when Hash
    out = expr.reject { |k, _| %w[resolved_type deps literal_type type_tag].include?(k) }.transform_values { |v| erased(v) }
    if out["kind"] == "call" && %w[stdlib.integer.add stdlib.integer.sub stdlib.integer.mul].include?(out["fn"])
      op = { "stdlib.integer.add" => "+", "stdlib.integer.sub" => "-", "stdlib.integer.mul" => "*" }.fetch(out["fn"])
      out = { "kind" => "binary_op", "op" => op, "left" => out["args"][0], "right" => out["args"][1] }
    end
    out
  when Array then expr.map { |v| erased(v) }
  else expr
  end
end

def fold_body(sir, contract)
  node(sir, contract, "total").fetch("expr").fetch("pipeline").find { |s| s["kind"] == "fold" }.fetch("body")
end

# A. the two named witnesses are let chains
status, rules, sir = compile("w1_rv02g_branch_let_float_shadow_ordinary.ig")
body = sir && fold_body(sir, "OrdinaryFold")
check("A1 rv02g admitted", status == "ok", rules.inspect)
check("A2 rv02g then-branch is `let r = 3.0` (was dropped: 32.0 for 6.0)",
      body && body.dig("then_branch", "kind") == "let" && body.dig("then_branch", "name") == "r" && body.dig("then_branch", "expr", "value") == 3.0,
      body.inspect[0, 200])
f = body ? facts(body) : nil
check("A3 rv02g carries [r], two Float orderings, nothing unlowered",
      f && f[:lets] == ["r"] && f[:ids].sort == %w[stdlib.float.gt stdlib.float.gt] && f[:unlowered].zero?, f.inspect)
status, rules, sir = compile("w2_rv12g_block_let_same_type_ordinary.ig")
body = sir && fold_body(sir, "OrdinaryFold")
check("A4 rv12g lambda block is a let chain (was the final expression alone: 2 for 3)",
      status == "ok" && body && body["kind"] == "let" && body["name"] == "r" && body.dig("body", "kind") == "if_expr", "#{status} #{rules.inspect}")
status, _rules, sir = compile("k2_block_bare_stmt_def.ig")
f = sir && facts(fold_body(sir, "O"))
check("A5 statements keep authored order; a bare statement binds __seq__", status == "ok" && f && f[:lets] == %w[r __seq__], f.inspect)
check("A6 def routing is preserved inside the let", sir && fold_body(sir, "O").dig("expr", "fn") == "user.R14.K2.twice",
      sir && fold_body(sir, "O").dig("expr", "fn").inspect)

# B. one tree: the ordinary body equals the stream carrier body (annotations erased). Specimens without a
# NESTED HOF: inside a shared callable the authored HOF call is kept (R10), while the ordinary route lowers
# a nested fold to its aggregate — a lawful difference of representation, not of statements.
%w[b1_then_shadow_else_outer k2_block_bare_stmt_def b3_int_outer_float_shadow].each do |id|
  status, _rules, sir = compile("#{id}.ig")
  carrier = sir && sir.fetch("callables", {}).values.first
  same = carrier && erased(fold_body(sir, "O")) == erased(carrier.fetch("body"))
  check("B #{id}: ordinary body == callable_v2 carrier body", status == "ok" && same,
        carrier ? JSON.generate(erased(fold_body(sir, "O")))[0, 160] : "no carrier")
end

# C. block-scoped branch typing on every route
status, rules, sir = compile("b3_int_outer_float_shadow.ig")
body = sir && fold_body(sir, "O")
check("C1 Integer outer / Float shadow admitted (was OOF-TY0)", status == "ok", rules.inspect)
check("C2 outer stdlib.integer.gt, inner stdlib.float.gt",
      body && body.dig("condition", "fn") == "stdlib.integer.gt" && body.dig("then_branch", "body", "condition", "fn") == "stdlib.float.gt")
status, rules, sir = compile("b4_float_outer_int_shadow.ig")
body = sir && fold_body(sir, "O")
check("C3 Float outer / Integer shadow: outer stdlib.float.gt, inner stdlib.integer.gt",
      status == "ok" && body && body.dig("condition", "fn") == "stdlib.float.gt" && body.dig("then_branch", "body", "condition", "fn") == "stdlib.integer.gt",
      "#{status} #{rules.inspect}")
status, rules, _sir = compile("x4b_effect_in_branch_let.ig")
check("C4 now() in a branch let refuses (was ADMITTED: the statement was dropped untyped)", status != "ok" && rules.include?("OOF-TY0"), "#{status} #{rules.inspect}")

# every owner: standalone HOF, aggregate stage, contract-level branch, String route
status, _rules, sir = compile("n2_capture_block_let.ig")
f = sir && facts(fold_body(sir, "O"))
check("A6b a nested fold that CAPTURES the block let keeps the let around it", status == "ok" && f[:lets] == ["r"] && f[:ids] == ["stdlib.float.gt"] && f[:unlowered].zero?, f.inspect)
status, _rules, sir = compile("h1_map_block.ig")
check("A7 standalone map block body", status == "ok" && facts(node(sir, "O", "ys")["expr"])[:lets] == ["x"])
status, _rules, sir = compile("h2_filter_block_count.ig")
f = sir && facts(node(sir, "O", "total")["expr"])
check("A8 filter block body under count", status == "ok" && f[:lets] == ["x"] && f[:ids] == ["stdlib.float.gt"], f.inspect)
status, _rules, sir = compile("v1_branch_shadow_input.ig")
expr = sir && node(sir, "O", "total")["expr"]
check("A9 contract-level branch let is carried", status == "ok" && expr.dig("then_branch", "kind") == "let" && expr.dig("else_branch", "kind") == "ref")
status, _rules, sir = compile("t1_string_block.ig")
body = sir && node(sir, "O", "joined")["expr"].fetch("pipeline").first.fetch("body")
check("A10 String routing inside the let", status == "ok" && body["kind"] == "let" && body.dig("expr", "fn") == "stdlib.string.concat", body.to_s[0, 120])

# D. deps are the node's free names
status, _rules, sir = compile("v1_branch_shadow_input.ig")
deps = sir && node(sir, "O", "total")["deps"]
check("D1 a let-bound read is not a dependency; the outer read is", status == "ok" && deps.sort == %w[base flag], deps.inspect)

# E. negatives
{ "x1_branch_let_out_of_scope.ig" => "OOF-P1", "x2_wrong_type.ig" => "OOF-COL4", "x3_arity.ig" => "OOF-COL4",
  "x4_effect_in_block_let.ig" => "OOF-EC6", "x5_reserved_seq.ig" => "OOF-COL4", "x6_unbound_name_in_let.ig" => "OOF-P1" }.each do |fixture, rule|
  status, rules, sir = compile(fixture)
  check("E #{fixture} refuses #{rule}", status != "ok" && rules.include?(rule) && sir.nil?, "#{status} #{rules.inspect}")
end

# E2. independent review F1: NO source value binder may spell the statement lowering's `__seq__` — each of these was
# admitted and silently computed the bare statement's value once the statement was carried (3 for 8, 6 for 100, …)
{ "y1_seq_input_branch_bare_stmt.ig" => "an input", "y2_seq_compute_name.ig" => "a compute name",
  "y3_seq_def_param.ig" => "a def parameter", "y4_seq_stream_input.ig" => "a stream contract's input",
  "y5_seq_def_body_let.ig" => "a def-body let", "y6_seq_loop_item.ig" => "a loop item",
  "y8_seq_match_binding.ig" => "a match-pattern binding",
  # re-check N1: an IO-REACHING def is never body-typed (its raw body is qualified and emitted), so the reservation
  # is checked for EVERY def ahead of that ownership choice
  "y9_seq_io_def_param.ig" => "an IO-reaching def's parameter", "y10_seq_io_def_toplevel_stmt.ig" => "an IO-reaching def's parameter (top-level bare statement)",
  "y11_seq_io_def_lambda_param.ig" => "a lambda parameter inside an IO-reaching def",
  # re-check N3 + the audit after it: the WHOLE declaration is walked, not a chosen field
  "y12_seq_stream_seed_lambda_param.ig" => "a lambda parameter in a fold_stream SEED",
  "y13_seq_invoke_arg_lambda_param.ig" => "a lambda parameter in an invoke argument" }.each do |fixture, what|
  status, rules, sir = compile(fixture)
  check("E2 #{what} spelled __seq__ refuses OOF-COL4", status != "ok" && rules.include?("OOF-COL4") && sir.nil?, "#{status} #{rules.inspect}")
end
status, rules, _sir = compile("y13c_invoke_arg_control.ig")
check("E2 CONTROL the same invoke argument WITHOUT the spelling is admitted", status == "ok", "#{status} #{rules.inspect}")
# re-check N4: `params` are binders only on a lambda or a def — a type's `params` are its type ARGUMENTS
%w[y14_seq_type_name_control.ig y14c_seq_def_param_type_control.ig].each do |fixture|
  status, rules, _sir = compile(fixture)
  check("E2 CONTROL a TYPE named __seq__ (#{fixture}) binds no value and is admitted", status == "ok", "#{status} #{rules.inspect}")
end
status, rules, sir = compile("y7_seq_field_control.ig")
expr = sir && node(sir, "O", "total")["expr"]
check("E2 CONTROL a record FIELD spelled __seq__ is not a binder", status == "ok" && expr.dig("then_branch", "name") == "__seq__" &&
      expr.dig("then_branch", "body", "args", 0, "kind") == "field_access", "#{status} #{rules.inspect}")

# A11. a def BODY shares the branch lowering: its branch-local let is carried (35 for 67 before, on the stream route too)
status, _rules, sir = compile("d1_def_body_branch_let.ig")
fn = sir && sir.fetch("functions", []).find { |f| f["name"] == "user.R14.D1.bump" }
check("A11 def-body branch let is carried", status == "ok" && fn && facts(fn["body"])[:lets] == ["a"], fn.inspect[0, 160])

# F. R14 locked this as a DECLARED RESIDUAL (the classifier, not an R14 owner, refused a fresh-named block let
# OOF-P1). LANG-CLASSIFIER-LEXICAL-BLOCK-DEPENDENCY-IMPLEMENTATION-R15 repaired the classifier's free-name walk,
# so the lock evolves deliberately: the same fixture is admitted and carried by the same let lowering. The
# classifier law itself is locked in experiments/r15_classifier_lexical_block_dependency_proof.
status, rules, sir = compile("c1_fresh_block_let.ig")
lets = sir && facts(node(sir, "O", "total")["expr"])[:lets]
check("F1 (evolved by R15) fresh-named lambda-block let is admitted and carried", status == "ok" && lets == ["d"], "#{status} #{rules.inspect} #{lets.inspect}")

puts "\n#{$pass} PASS / #{$fail} FAIL"
exit($fail.zero? ? 0 : 1)
