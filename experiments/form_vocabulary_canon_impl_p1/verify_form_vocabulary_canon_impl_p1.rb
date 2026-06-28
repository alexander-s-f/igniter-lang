#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"

ROOT = File.expand_path("../..", __dir__)
$LOAD_PATH.unshift(File.join(ROOT, "lib"))
require "igniter_lang"

$checks = []

def check(name)
  ok = yield
  $checks << [name, ok]
  puts "#{ok ? 'PASS' : 'FAIL'} #{name}"
rescue => e
  $checks << [name, false]
  puts "FAIL #{name} (#{e.class}: #{e.message})"
end

def write(path, text)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, text)
end

def elements_source(extra_contracts: "")
  <<~IG
    module UI.Elements

    type Element {
      tag : String
      text : String
      children : Collection[Element]
    }

    pure contract leaf {
      input text : String
      compute node : Element = { tag: "leaf", text: text, children: [] }
      output node : Element
    }

    pure contract col {
      input children : Collection[Element]
      compute node : Element = { tag: "col", text: "", children: children }
      output node : Element
    }

    pure contract caption {
      input text : String
      compute node : Element = { tag: "caption", text: text, children: [] }
      output node : Element
    }

    #{extra_contracts}
  IG
end

def compile_case(page_source, elements: elements_source)
  dir = Dir.mktmpdir("ig_form_vocab_p1")
  elements_path = File.join(dir, "elements.ig")
  page_path = File.join(dir, "page.ig")
  out_path = File.join(dir, "out.igapp")
  write(elements_path, elements)
  write(page_path, page_source)
  result = IgniterLang::CompilerOrchestrator.new.compile_sources(
    source_paths: [elements_path, page_path],
    out_path: out_path
  )
  [result, out_path]
end

def public_result(result)
  IgniterLang::CompilerResult.public_result(result.fetch("result"))
end

def diagnostics(result)
  public_result(result).fetch("diagnostics", [])
end

def page_form_node(out_path)
  sir = JSON.parse(File.read(File.join(out_path, "semantic_ir_program.json")))
  page = sir.fetch("contracts").find { |c| c.fetch("contract_name") == "Page" }
  page.fetch("nodes").find { |n| n.fetch("name") == "view" }.fetch("expr")
end

POSITIVE_PAGE = <<~IG
  module App.Page
  import UI.Elements.{ col, leaf }

  pure contract Page {
    uses col
    uses leaf
    compute view : Element = col {
      leaf text="Ada" {}
    }
    output view : Element
  }
IG

check("A-01 positive form invocation compiles through igapp") do
  result, = compile_case(POSITIVE_PAGE)
  public_result(result).fetch("status") == "ok"
end

check("A-02 nested form invocation resolves through imported uses refs") do
  result, out_path = compile_case(POSITIVE_PAGE)
  node = page_form_node(out_path)
  child = node.fetch("args").first.fetch("expr").fetch("items").first
  public_result(result).fetch("status") == "ok" &&
    node.fetch("kind") == "form_invocation" &&
    node.fetch("trigger") == "col" &&
    node.fetch("resolved_ref").fetch("module_name") == "UI.Elements" &&
    child.fetch("trigger") == "leaf" &&
    child.fetch("resolved_ref").fetch("module_name") == "UI.Elements"
end

check("A-03 form invocation carries no call_contract dispatch") do
  result, out_path = compile_case(POSITIVE_PAGE)
  node_json = JSON.generate(page_form_node(out_path))
  public_result(result).fetch("status") == "ok" &&
    !node_json.include?("call_contract")
end

RECORD_PAGE = <<~IG
  module App.Page
  import UI.Elements.{ caption }

  pure contract Page {
    uses caption
    compute direct : Element = { tag: "direct", text: "record", children: [] }
    compute view : Element = caption text="Ada" {}
    output view : Element
  }
IG

check("B-01 record literal key:value remains distinct from form key=value") do
  result, out_path = compile_case(RECORD_PAGE)
  sir = JSON.parse(File.read(File.join(out_path, "semantic_ir_program.json")))
  page = sir.fetch("contracts").find { |c| c.fetch("contract_name") == "Page" }
  direct = page.fetch("nodes").find { |n| n.fetch("name") == "direct" }.fetch("expr")
  view = page.fetch("nodes").find { |n| n.fetch("name") == "view" }.fetch("expr")
  public_result(result).fetch("status") == "ok" &&
    direct.fetch("kind") == "record_literal" &&
    view.fetch("kind") == "form_invocation"
end

UNKNOWN_TRIGGER_PAGE = <<~IG
  module App.Page
  import UI.Elements.{ leaf }

  pure contract Page {
    uses leaf
    compute view : Element = col {
      leaf text="Ada" {}
    }
    output view : Element
  }
IG

check("C-01 unknown trigger without uses fails closed") do
  result, = compile_case(UNKNOWN_TRIGGER_PAGE)
  diagnostics(result).any? { |d| d.fetch("rule") == "OOF-FORM1" }
end

EXTRA_ATTR_PAGE = <<~IG
  module App.Page
  import UI.Elements.{ leaf }

  pure contract Page {
    uses leaf
    compute view : Element = leaf text="Ada" tone="warm" {}
    output view : Element
  }
IG

check("C-02 unknown form attribute fails closed") do
  result, = compile_case(EXTRA_ATTR_PAGE)
  diagnostics(result).any? { |d| d.fetch("rule") == "OOF-FORM4" }
end

BAD_CHILD_PAGE = <<~IG
  module App.Page
  import UI.Elements.{ leaf }

  pure contract Page {
    uses leaf
    compute view : Element = leaf text="Ada" {
      leaf text="Nested" {}
    }
    output view : Element
  }
IG

check("C-03 children require a target children input") do
  result, = compile_case(BAD_CHILD_PAGE)
  diagnostics(result).any? { |d| d.fetch("rule") == "OOF-FORM5" }
end

TYPE_MISMATCH_PAGE = <<~IG
  module App.Page
  import UI.Elements.{ leaf }

  pure contract Page {
    uses leaf
    compute view : Element = leaf text=42 {}
    output view : Element
  }
IG

check("C-04 attribute type mismatch fails closed") do
  result, = compile_case(TYPE_MISMATCH_PAGE)
  diagnostics(result).any? { |d| d.fetch("rule") == "OOF-FORM7" }
end

puts
failures = $checks.reject { |_, ok| ok }
if failures.empty?
  puts "LANG-FORM-VOCABULARY-P4-CANON-IMPL-P1 PASS (#{$checks.length}/#{$checks.length})"
  exit 0
else
  puts "LANG-FORM-VOCABULARY-P4-CANON-IMPL-P1 FAIL (#{failures.length}/#{$checks.length})"
  exit 1
end
