#!/usr/bin/env ruby
# frozen_string_literal: true

# Track: LANG-SECRET-REF-NATIVE-P2
# Agent: [Igniter-Lang Implementation Agent]
#
# Proof that the Ruby/canon toolchain implements native sealed `SecretRef` at type/emit parity
# with the Rust toolchain: the sole `secret_ref("name")` constructor lowers to a dedicated,
# sealed `secret_ref` SemanticIR node (name only, never plaintext); the reference name must match
# the shared grammar AND the explicit declared-allowlist compile context; every illegal
# construction / observation refuses with `OOF-SR1` and no diagnostic echoes the reference literal.
#
# Ruby has no lab project resolver, so the declared allowlist is supplied as an explicit compile
# context (`TypeChecker.new(declared_secret_refs: [...])`) — the same set Rust reads from
# `[app] secret_refs`. Proof-local: writes ONLY to experiments/secret_ref_native_proof/out/.

require "fileutils"
require "json"
require "pathname"

require_relative "../../lib/igniter_lang/compiler_orchestrator"

module SecretRefNativeProof
  ROOT    = Pathname.new(File.expand_path("../..", __dir__))
  OUT_DIR = ROOT / "experiments/secret_ref_native_proof/out"
  DECLARED = ["sparkcrm.api_token", "dispatch.smtp_password"].freeze

  module_function

  def orchestrator(declared:)
    IgniterLang::CompilerOrchestrator.new(
      typechecker: IgniterLang::TypeChecker.new(declared_secret_refs: declared)
    )
  end

  def compile(src, tag:, declared: DECLARED)
    FileUtils.mkdir_p(OUT_DIR)
    sp = OUT_DIR / "#{tag}.ig"
    File.write(sp, src)
    orchestrator(declared: declared).compile(source_path: sp.to_s, out_path: (OUT_DIR / "#{tag}.igapp").to_s)
  end

  def diagnostics(result)
    (result["diagnostics"] || result.dig("compilation_report", "diagnostics") || []).map { |d| d.is_a?(Hash) ? d : {} }
  end

  def rules(result)
    diagnostics(result).map { |d| d["rule"] }.compact
  end

  def sir_text(result)
    JSON.generate(result["semantic_ir"] || {})
  end

  CONTRACT = lambda do |body|
    "module App.Main\n\npure contract C {\n#{body}\n}\n\nentrypoint C\n"
  end

  def run
    failures = []
    check = lambda do |name, cond|
      failures << name unless cond
      puts "  #{cond ? "PASS" : "FAIL"}  #{name}"
    end

    # 1. Declared literal → sealed secret_ref node carrying the reference name; type SecretRef.
    ok = compile(CONTRACT.call(
      "  compute r : SecretRef = secret_ref(\"sparkcrm.api_token\")\n  output r : SecretRef"
    ), tag: "ok")
    sir = sir_text(ok)
    check.call("ok compile status", ok["status"] == "ok")
    check.call("emits secret_ref node", sir.include?("\"kind\":\"secret_ref\"") || sir.include?("\"kind\": \"secret_ref\""))
    check.call("carries reference name", sir.include?("sparkcrm.api_token"))
    check.call("resolved type is SecretRef", sir.include?("SecretRef"))

    # 2. Undeclared name → OOF-SR1, no literal echo.
    und = compile(CONTRACT.call(
      "  compute r : SecretRef = secret_ref(\"totally.undeclared\")\n  output r : SecretRef"
    ), tag: "undeclared")
    check.call("undeclared → OOF-SR1", rules(und).include?("OOF-SR1"))
    check.call("undeclared diagnostic hides literal",
               diagnostics(und).none? { |d| d["message"].to_s.include?("totally.undeclared") })

    # 3. Dynamic / non-literal argument → OOF-SR1.
    dyn = compile(CONTRACT.call(
      "  compute k : String = \"sparkcrm.api_token\"\n  compute r : SecretRef = secret_ref(k)\n  output r : SecretRef"
    ), tag: "dynamic")
    check.call("dynamic arg → OOF-SR1", rules(dyn).include?("OOF-SR1"))

    # 4. No declaration context (nil) → every reference refused fail-closed.
    noctx = compile(CONTRACT.call(
      "  compute r : SecretRef = secret_ref(\"sparkcrm.api_token\")\n  output r : SecretRef"
    ), tag: "noctx", declared: nil)
    check.call("no context → OOF-SR1", rules(noctx).include?("OOF-SR1"))

    # 5. Equality / observation → OOF-SR1.
    eq = compile(CONTRACT.call(
      "  compute r : SecretRef = secret_ref(\"sparkcrm.api_token\")\n  compute b : Bool = r == r\n  output b : Bool"
    ), tag: "equality")
    check.call("equality → OOF-SR1", rules(eq).include?("OOF-SR1"))

    puts(failures.empty? ? "\nSecretRef Ruby parity: ALL PASS" : "\nSecretRef Ruby parity: FAILED #{failures.inspect}")
    exit(failures.empty? ? 0 : 1)
  end
end

SecretRefNativeProof.run if $PROGRAM_NAME == __FILE__
