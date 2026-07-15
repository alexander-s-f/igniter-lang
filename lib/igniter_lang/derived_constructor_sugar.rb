# frozen_string_literal: true

require "set"

require_relative "contract_call_sugar"

module IgniterLang
  # LANG-DERIVED-RECORD-CONSTRUCTOR-P2
  #
  # Whole-program, pre-classify lowering for the contextual structural
  # constructor surface. Parser placeholders deliberately occupy the existing
  # contracts collection so declaration order, imports, duplicate checks and
  # origin-module identity use the ordinary contract machinery. This pass:
  #
  # * replaces each valid placeholder with the canonical pure ContractDecl;
  # * rewrites named construction to the existing static call_contract form;
  # * refuses positional calls and every ambiguous/incomplete named call; and
  # * removes every constructor-kind node before classify/typecheck/emit.
  #
  # No constructor node, value, opcode or runtime authority survives this pass.
  module DerivedConstructorSugar
    module_function

    def lower!(parsed, scope: nil)
      return parsed unless parsed.is_a?(Hash)

      contracts = Array(parsed["contracts"])
      placeholders = contracts.select { |contract| contract.is_a?(Hash) && contract["kind"] == "constructor" }
      return parsed if placeholders.empty?

      errors = parsed["parse_errors"] ||= []
      type_groups = Array(parsed["types"]).each_with_object(Hash.new { |hash, name| hash[name] = [] }) do |type, index|
        index[type["name"]] << type if type.is_a?(Hash) && type["name"]
      end
      # Multifile resolution normally rejects duplicate TypeDecl names before
      # this pass, but the flat compiler path must fail closed too. Only unique
      # declarations participate in target/recursion resolution.
      type_map = type_groups.filter_map do |name, declarations|
        [name, declarations.first] if declarations.length == 1
      end.to_h
      variant_arm_names = Array(parsed["variants"]).flat_map do |variant|
        Array(variant["arms"]).filter_map { |arm| arm["name"] if arm.is_a?(Hash) }
      end.to_set
      function_names = Array(parsed["functions"]).filter_map { |function| function["name"] }.to_set

      constructor_infos = Hash.new { |hash, name| hash[name] = [] }
      parsed["contracts"] = contracts.filter_map do |contract|
        next contract unless contract.is_a?(Hash) && contract["kind"] == "constructor"

        lowered, info = lower_constructor(contract, type_groups, type_map, errors, parsed, scope)
        constructor_infos[info.fetch("name")] << info if info
        lowered
      end

      rewrite_program(parsed, constructor_infos, variant_arm_names, errors, scope, function_names)
      parsed
    end

    def lower_constructor(constructor, type_groups, type_map, errors, parsed, scope)
      name = constructor.fetch("name", "<invalid>")
      origin_module = constructor["origin_module"] || parsed["module"]
      outputs = Array(constructor["body"]).select { |decl| decl.is_a?(Hash) && decl["kind"] == "output" }

      if outputs.empty?
        diagnostic(errors, constructor, "OOF-CTOR1",
                   "constructor '#{name}' must declare exactly one named record output")
        return [nil, nil]
      end

      if outputs.length > 1
        diagnostic(
          errors,
          constructor,
          "OOF-RET1",
          "contract '#{name}' declares #{outputs.length} outputs; a contract returns exactly one value — " \
          "define a named result record and return it: type #{name}Result { ... }; output result : #{name}Result"
        )
        return [nil, nil]
      end

      output = outputs.first
      target_annotation = output["type_annotation"]
      target_name = target_annotation if target_annotation.is_a?(String)
      target_declarations = target_name ? type_groups.fetch(target_name, []) : []
      target = target_declarations.length == 1 ? target_declarations.first : nil
      fields = target && Array(target["fields"])
      unique_field_names = fields && fields.map { |field| field["name"] }.compact.uniq.length == fields.length
      target_origin = target_name && scope && scope.fetch("type_modules", {})[target_name]
      target_visible = !scope || visible_item?(scope, origin_module, target_origin, target_name)

      unless target_name && target && fields.any? && unique_field_names && target_visible
        diagnostic(
          errors,
          constructor,
          "OOF-CTOR1",
          "constructor '#{name}' target '#{type_display(target_annotation)}' must be a visible " \
          "non-generic record type with at least one field"
        )
        return [nil, nil]
      end

      if recursive_record?(target_name, type_map)
        diagnostic(
          errors,
          constructor,
          "OOF-CTOR1",
          "constructor '#{name}' target '#{target_name}' is recursive; recursive record targets are held in v0"
        )
        return [nil, nil]
      end

      output_name = output.fetch("name")
      record_fields = fields.each_with_object({}) do |field, result|
        field_name = field.fetch("name")
        result[field_name] = { "kind" => "ref", "name" => field_name }
      end
      body = fields.map do |field|
        {
          "kind" => "input",
          "name" => field.fetch("name"),
          "type_annotation" => field.fetch("type_annotation")
        }
      end
      body << {
        "kind" => "compute",
        "name" => output_name,
        "expr" => { "kind" => "record_literal", "fields" => record_fields },
        "type_annotation" => target_annotation
      }
      body << { "kind" => "output", "name" => output_name, "type_annotation" => target_annotation }

      lowered = {
        "kind" => "contract",
        "name" => name,
        "modifier" => "pure",
        "type_params" => [],
        "body" => body
      }
      lowered["origin_module"] = constructor["origin_module"] if constructor.key?("origin_module")

      info = {
        "name" => name,
        "origin_module" => origin_module,
        "field_names" => fields.map { |field| field.fetch("name") }
      }
      [lowered, info]
    end

    # Multifile lowering cannot treat the merged universe as one lexical scope:
    # selective imports and same-module ownership remain ordinary contract
    # authority even though the source units have been merged. Rewrite every
    # top-level declaration under its original module. Single-file compilation
    # keeps the former exhaustive whole-program walk.
    def rewrite_program(parsed, constructor_infos, variant_arm_names, errors, scope, function_names)
      unless scope
        rewrite(
          parsed,
          constructor_infos,
          variant_arm_names,
          errors,
          nil,
          parsed["module"],
          function_names
        )
        return
      end

      Array(parsed["contracts"]).each do |contract|
        current_module = contract["origin_module"] || parsed["module"]
        rewrite(contract, constructor_infos, variant_arm_names, errors, scope, current_module, function_names)
      end

      scope.fetch("collection_modules", {}).each do |collection, modules|
        next if collection == "contracts"

        Array(parsed[collection]).each_with_index do |declaration, index|
          rewrite(
            declaration,
            constructor_infos,
            variant_arm_names,
            errors,
            scope,
            modules[index],
            function_names
          )
        end
      end
    end

    def rewrite(node, constructor_infos, variant_arm_names, errors, scope, current_module, function_names)
      case node
      when Array
        node.each do |value|
          rewrite(value, constructor_infos, variant_arm_names, errors, scope, current_module, function_names)
        end
      when Hash
        node.each do |key, value|
          next if key == "parse_errors"

          rewrite(value, constructor_infos, variant_arm_names, errors, scope, current_module, function_names)
        end

        if node["kind"] == "call"
          refuse_positional_call(
            node,
            constructor_infos,
            errors,
            scope,
            current_module,
            function_names
          )
        elsif node["kind"] == "variant_construct"
          lower_named_invocation(
            node,
            constructor_infos,
            variant_arm_names,
            errors,
            scope,
            current_module
          )
        end
      end
    end

    def refuse_positional_call(node, constructor_infos, errors, scope, current_module, function_names)
      name = node["fn"]
      return unless name.is_a?(String)
      # Natural contract calls are a fallback surface: a same-module `def` wins
      # and reserved builtins always keep their established meaning.
      return if ContractCallSugar::RESERVED.include?(name)
      return if visible_function?(scope, current_module, name, function_names)

      candidates = visible_constructors(constructor_infos[name], scope, current_module)
      return if candidates.empty?

      if candidates.length > 1
        ambiguous_constructor_diagnostic(errors, node, name)
        return
      end

      diagnostic(
        errors,
        node,
        "OOF-CTOR4",
        "constructor '#{name}' does not accept positional invocation; use `#{name} { field: ... }`",
        token: name
      )
    end

    def lower_named_invocation(node, constructor_infos, variant_arm_names, errors, scope, current_module)
      name = node["arm"]
      candidates = visible_constructors(constructor_infos[name], scope, current_module)
      return if candidates.empty?

      if candidates.length > 1
        ambiguous_constructor_diagnostic(errors, node, name)
        return
      end

      if visible_variant_arm?(variant_arm_names, name, scope, current_module)
        diagnostic(
          errors,
          node,
          "OOF-CTOR5",
          "named construction '#{name} { ... }' is ambiguous between a constructor and a variant arm; " \
          "rename one declaration or use explicit call_contract",
          token: name
        )
        return
      end

      info = candidates.first
      expected = info.fetch("field_names")
      fields = node["fields"].is_a?(Hash) ? node["fields"] : {}
      missing = (expected - fields.keys).sort
      extra = (fields.keys - expected).sort

      unless missing.empty?
        diagnostic(
          errors,
          node,
          "OOF-CTOR7",
          "constructor '#{name}' invocation is missing required field(s): #{missing.join(', ')}",
          token: name
        )
      end
      unless extra.empty?
        diagnostic(
          errors,
          node,
          "OOF-CTOR8",
          "constructor '#{name}' invocation has unknown field(s): #{extra.join(', ')}",
          token: name
        )
      end
      return unless missing.empty? && extra.empty?

      args = expected.map { |field_name| fields.fetch(field_name) }
      callee_name = qualified_callee_name(info, current_module)
      node.replace(
        "kind" => "call",
        "fn" => "call_contract",
        "args" => [
          { "kind" => "literal", "value" => callee_name, "type_tag" => "String" },
          *args
        ]
      )
    end

    def visible_constructors(candidates, scope, current_module)
      Array(candidates).select do |candidate|
        visible_item?(
          scope,
          current_module,
          candidate["origin_module"],
          candidate.fetch("name")
        )
      end
    end

    def visible_variant_arm?(variant_arm_names, arm_name, scope, current_module)
      return variant_arm_names.include?(arm_name) unless scope

      Array(scope.fetch("variant_arm_owners", {})[arm_name]).any? do |owner|
        visible_item?(
          scope,
          current_module,
          owner["module"],
          owner["variant_name"]
        )
      end
    end

    def visible_function?(scope, current_module, name, function_names)
      return function_names.include?(name) unless scope

      Array(scope.fetch("function_modules", {})[name]).include?(current_module)
    end

    def visible_item?(scope, current_module, owner_module, item_name)
      return true unless scope
      return false if current_module.to_s.empty? || owner_module.to_s.empty?
      return true if current_module == owner_module

      Array(scope.fetch("per_module_imports", {})[current_module]).any? do |import|
        next false unless import["module_path"] == owner_module

        names = import["names"]
        names.nil? || names.include?(item_name)
      end
    end

    def qualified_callee_name(info, current_module)
      owner = info["origin_module"]
      return info.fetch("name") if owner.to_s.empty? || owner == current_module

      "#{owner}.#{info.fetch('name')}"
    end

    def ambiguous_constructor_diagnostic(errors, node, name)
      diagnostic(
        errors,
        node,
        "OOF-DECL-AMBIGUOUS-CONTRACT",
        "constructor invocation '#{name}' is ambiguous because multiple visible constructors declare " \
        "'#{name}'; use an explicit qualified call_contract",
        token: name
      )
    end

    def recursive_record?(name, type_map, visiting = Set.new, visited = Set.new)
      return true if visiting.include?(name)
      return false if visited.include?(name)

      visiting.add(name)
      type = type_map[name]
      recursive = Array(type && type["fields"]).any? do |field|
        type_references(field["type_annotation"]).any? do |ref|
          type_map.key?(ref) && recursive_record?(ref, type_map, visiting, visited)
        end
      end
      visiting.delete(name)
      visited.add(name)
      recursive
    end

    def type_references(annotation)
      case annotation
      when String
        [annotation]
      when Array
        annotation.flat_map { |value| type_references(value) }
      when Hash
        [annotation["name"], *type_references(annotation["params"] || [])].compact
      else
        []
      end
    end

    def type_display(annotation)
      return "<missing>" if annotation.nil?
      return annotation unless annotation.is_a?(Hash)

      name = annotation["name"] || annotation["constructor"] || "Unknown"
      params = Array(annotation["params"])
      return name if params.empty?

      "#{name}[#{params.map { |param| type_display(param) }.join(', ')}]"
    end

    def diagnostic(errors, node, rule, message, token: nil)
      span = node["source_span"].is_a?(Hash) ? node["source_span"] : {}
      errors << {
        "rule" => rule,
        "severity" => "error",
        "message" => message,
        "token" => token || node["name"] || node["arm"] || node["fn"],
        "line" => span["line"],
        "col" => span["col"]
      }
    end
  end
end
