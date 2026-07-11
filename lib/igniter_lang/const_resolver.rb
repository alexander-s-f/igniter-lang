# frozen_string_literal: true

module IgniterLang
  # Compile-time-only module constant resolution. Declarations remain parse
  # evidence; every use becomes an ordinary literal AST before classification.
  module ConstResolver
    module_function

    def resolve_single!(parsed) = resolve_programs!([parsed])

    def resolve_programs!(programs)
      diagnostics = []
      declarations = {}
      programs.each do |program|
        mod = program.fetch("module", "").to_s
        program.fetch("consts", []).each do |decl|
          key = [mod, decl.fetch("name")]
          if declarations.key?(key)
            diagnostics << diagnostic("OOF-DECL-DUP-CONST", "duplicate const declaration '#{decl.fetch('name')}'", decl.fetch("name"))
          else
            declarations[key] = decl
          end
        end
      end
      return diagnostics unless diagnostics.empty?

      resolved = {}
      visiting = []
      resolve = lambda do |key|
        return resolved[key] if resolved.key?(key)
        if visiting.include?(key)
          cycle = (visiting[visiting.index(key)..] + [key]).map { |m, n| m.empty? ? n : "#{m}.#{n}" }
          diagnostics << diagnostic("OOF-CONST-CYCLE", "const cycle detected: #{cycle.join(' -> ')}", key.last)
          return nil
        end
        decl = declarations[key]
        return nil unless decl
        visiting << key
        program = programs.find { |candidate| candidate.fetch("module", "").to_s == key.first }
        value = fold_const_expr(decl.fetch("expr"), visible_consts(program, declarations), resolve, diagnostics, key)
        visiting.pop
        if value
          resolved[key] = value
          decl["resolved_expr"] = deep_copy(value)
        end
        value
      end
      declarations.keys.sort.each { |key| resolve.call(key) }
      return diagnostics unless diagnostics.empty?

      programs.each do |program|
        visible = visible_consts(program, declarations)
        program.each do |key, value|
          next if %w[consts imports types variants].include?(key)
          program[key] = inline_refs(value, visible, resolved)
        end
      end
      diagnostics
    end

    def visible_consts(program, declarations)
      return {} unless program
      mod = program.fetch("module", "").to_s
      visible = declarations.each_with_object({}) { |((m, n), _), h| h[n] = [m, n] if m == mod }
      program.fetch("imports", []).each do |imp|
        next unless imp.fetch("names", nil)
        imp.fetch("names").each do |name|
          key = [imp.fetch("module_path"), name]
          visible[name] = key if declarations.key?(key)
        end
      end
      visible
    end

    def fold_const_expr(expr, visible, resolve, diagnostics, owner)
      case expr.fetch("kind", nil)
      when "literal" then deep_copy(expr)
      when "ref"
        key = visible[expr.fetch("name")]
        unless key
          diagnostics << diagnostic("OOF-CONST-UNKNOWN", "unknown const reference '#{expr.fetch('name')}' in '#{owner.last}'", owner.last)
          return nil
        end
        value = resolve.call(key)
        value && deep_copy(value)
      when "array_literal"
        items = expr.fetch("items").map { |item| fold_const_expr(item, visible, resolve, diagnostics, owner) }
        items.all? ? { "kind" => "array_literal", "items" => items } : nil
      when "record_literal"
        fields = expr.fetch("fields").transform_values { |value| fold_const_expr(value, visible, resolve, diagnostics, owner) }
        fields.values.all? ? { "kind" => "record_literal", "fields" => fields } : nil
      else
        diagnostics << diagnostic("OOF-CONST-LITERAL", "const '#{owner.last}' RHS is not a literal expression", owner.last)
        nil
      end
    end

    def inline_refs(value, visible, resolved)
      case value
      when Array then value.map { |item| inline_refs(item, visible, resolved) }
      when Hash
        if value.fetch("kind", nil) == "ref" && (key = visible[value.fetch("name")]) && resolved[key]
          deep_copy(resolved.fetch(key))
        else
          value.transform_values { |item| inline_refs(item, visible, resolved) }
        end
      else value
      end
    end

    def diagnostic(rule, message, node)
      { "rule" => rule, "severity" => "error", "message" => message, "node" => node }
    end

    def deep_copy(value) = Marshal.load(Marshal.dump(value))
  end
end
