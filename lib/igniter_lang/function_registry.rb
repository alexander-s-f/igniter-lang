# frozen_string_literal: true

require "set"

module IgniterLang
  # LANG-APP-LOCAL-DEF-CALL-CANON-ADOPTION-P2 (PROP-051 §1.1): the authoritative
  # module-scoped function registry `(module, name) → FunctionDecl` lives in the
  # TypeChecker (built once per typecheck over the classified program). This
  # module is the ONE shared pre-classification name view of the same `def`
  # declarations for passes that run before module attribution exists (the
  # contract-call and derived-constructor sugar passes only need "is this name a
  # declared def" to give defs precedence) — not a second registry.
  module FunctionRegistry
    module_function

    # Bare declared `def` names of a parsed program, as a Set.
    def declared_names(parsed)
      functions = parsed.is_a?(Hash) ? parsed["functions"] : nil
      Array(functions).filter_map { |fn| fn["name"] if fn.is_a?(Hash) }.to_set
    end
  end
end
